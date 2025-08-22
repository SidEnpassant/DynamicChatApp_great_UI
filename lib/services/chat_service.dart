import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamichatapp/OneSignalAppCredentials.dart';
import 'package:dynamichatapp/models/user_profile.dart';
import 'package:dynamichatapp/models/group_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UserProfile?> searchUserByPhoneNumber(String phoneNumber) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return UserProfile.fromMap(querySnapshot.docs.first.data());
    }
    return null;
  }

  Future<void> addContact(UserProfile contact) async {
    final currentUser = _auth.currentUser!;

    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final currentUserProfile = UserProfile.fromMap(
      currentUserDoc.data() as Map<String, dynamic>,
    );

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .doc(contact.uid)
        .set(contact.toMap());

    await _firestore
        .collection('users')
        .doc(contact.uid)
        .collection('contacts')
        .doc(currentUser.uid)
        .set(currentUserProfile.toMap());
  }

  Stream<List<String>> getContactsStream() {
    final currentUser = _auth.currentUser!;
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        });
  }

  Stream<List<UserProfile>> getContactsProfilesStream() {
    final currentUser = _auth.currentUser!;
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('contacts')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserProfile.fromMap(doc.data()))
              .toList();
        });
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  Future<void> sendMessage(
    String receiverId, {
    String? text,
    String? imageUrl,
    Message? repliedToMessage,
    required bool isGroup,
  }) async {
    if (text == null && imageUrl == null) return;

    String type = 'text';
    if (imageUrl != null) type = 'image';

    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>;

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,

      senderName: userData['email'].toString().split('@')[0],
      senderPhotoURL: userData['photoURL'],

      receiverId: receiverId,
      message: text ?? '',
      imageUrl: imageUrl,
      type: imageUrl != null ? 'image' : 'text',
      timestamp: timestamp,
      reactions: {},
      isReply: repliedToMessage != null,
      replyingToMessage: repliedToMessage?.message,
      replyingToSender: repliedToMessage?.senderEmail,

      readBy: {currentUserId: Timestamp.now()},
    );

    if (isGroup) {
      // 📌 Save in "groups/{groupId}/messages"
      await _firestore
          .collection('groups')
          .doc(receiverId)
          .collection('messages')
          .add(newMessage.toMap());

      await _firestore.collection('groups').doc(receiverId).update({
        'lastMessage': text ?? "Sent an image",
        'lastMessageTimestamp': Timestamp.now(),
      });
    } else {
      // 📌 Private chat (chat_rooms)
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      String chatRoomId = ids.join('_');

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(newMessage.toMap());

      await _sendOneSignalNotification(
        receiverId: receiverId,
        senderEmail: currentUserEmail,
        message: text,
        imageUrl: imageUrl,
      );
    }
  }

  Future<void> toggleMessageReaction(
    String chatRoomId,
    String messageId,
    String emoji,
  ) async {
    final currentUserId = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(messageRef);

      if (!snapshot.exists) {
        throw Exception("Message does not exist!");
      }

      Map<String, List<String>> reactions = Map<String, List<String>>.from(
        (snapshot.data()!['reactions'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      );

      String? previousReaction;

      reactions.forEach((key, userList) {
        if (userList.contains(currentUserId)) {
          previousReaction = key;
          userList.remove(currentUserId);
        }
      });

      reactions.removeWhere((key, userList) => userList.isEmpty);

      if (previousReaction != emoji) {
        List<String> newUserList = reactions[emoji] ?? [];
        newUserList.add(currentUserId);
        reactions[emoji] = newUserList;
      }

      transaction.update(messageRef, {'reactions': reactions});
    });
  }

  Future<List<UserProfile>> getUsersByIdsOnce(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final snapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    return snapshot.docs.map((doc) => UserProfile.fromMap(doc.data())).toList();
  }

  Future<void> _sendOneSignalNotification({
    required String receiverId,
    required String senderEmail,
    String? message,
    String? imageUrl,
  }) async {
    const String oneSignalAppId = OnesignalappCredentials.OneSignalId;
    const String oneSignalRestApiKey = OnesignalappCredentials.OneSignaAPI_KEY;

    final String notificationContent = imageUrl != null
        ? "Sent you an image."
        : message!;

    final body = {
      "app_id": oneSignalAppId,
      "include_external_user_ids": [receiverId],
      "headings": {"en": "New message from $senderEmail"},
      "contents": {"en": notificationContent},
      "android_group": "chat_app_group",
    };

    try {
      final response = await http.post(
        Uri.parse("https://onesignal.com/api/v1/notifications"),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Basic $oneSignalRestApiKey",
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print("OneSignal notification sent successfully.");
      } else {
        print("Failed to send OneSignal notification: ${response.body}");
      }
    } catch (e) {
      print("Error sending OneSignal notification: $e");
    }
  }

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> updateTypingStatus(
    String chatRoomId,
    String userId,
    bool isTyping,
  ) async {
    final chatRoomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    await chatRoomRef.set({
      'typingStatus': {userId: isTyping},
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getChatRoomStream(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }

  Stream<QuerySnapshot> getUsersByIdsStream(List<String> ids) {
    if (ids.isEmpty) {
      return Stream.empty();
    }
    return _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots();
  }

  // ============================================================
  // =============== NEW GROUP CHAT FEATURES ====================
  // ============================================================
  Future<void> markMessageAsRead(
    String groupId,
    String messageId,
    bool isGroupChat,
  ) async {
    final currentUserId = _auth.currentUser!.uid;

    final collectionPath = isGroupChat ? 'groups' : 'chat_rooms';
    final messageRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

    // Use dot notation for updating a specific field in a map
    // await messageRef.update({'readBy.$currentUserId': Timestamp.now()});
    try {
      // This update only writes the timestamp if the user's ID is not already a key in the map.
      // This is efficient and prevents unnecessary writes.
      await messageRef.update({'readBy.$currentUserId': Timestamp.now()});
    } on FirebaseException catch (e) {
      // This will help you debug if the error persists by showing exactly what path is failing.
      print("Permission denied on path: ${messageRef.path}");
      print("Error: ${e.message}");
    }
  }

  Future<void> _sendSystemMessage(String groupId, String text) async {
    final Message systemMessage = Message(
      senderId: 'system', // Special ID for system messages
      senderEmail: 'system',
      receiverId: groupId,
      message: text,
      timestamp: Timestamp.now(),
      type: 'system', // A new message type
      reactions: {},
      readBy: {},
    );

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(systemMessage.toMap());
  }

  Future<void> updateGroupDetails(
    String groupId,
    String newName,
    String newDescription,
  ) async {
    await _firestore.collection('groups').doc(groupId).update({
      'groupName': newName,
      'description': newDescription,
    });
  }

  Future<void> updateGroupIcon(String groupId, XFile image) async {
    try {
      final ref = _storage.ref().child('group_icons').child('$groupId.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await _firestore.collection('groups').doc(groupId).update({
        'groupIcon': url,
      });
    } catch (e) {
      print("Error uploading group icon: $e");
    }
  }

  Future<void> addMembersToGroup(
    String groupId,
    List<UserProfile> newMembers,
  ) async {
    final memberIds = newMembers.map((e) => e.uid).toList();
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion(memberIds),
    });

    // Send a system message for each new member
    for (var member in newMembers) {
      await _sendSystemMessage(
        groupId,
        "${member.email.split('@')[0]} joined the group.",
      );
    }
  }

  Future<void> removeMemberFromGroup(
    String groupId,
    UserProfile memberToRemove,
  ) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([memberToRemove.uid]),
      'admins': FieldValue.arrayRemove([
        memberToRemove.uid,
      ]), // Also remove from admin list if they are one
    });
    await _sendSystemMessage(
      groupId,
      "${memberToRemove.email.split('@')[0]} was removed.",
    );
  }

  Future<void> promoteToAdmin(String groupId, UserProfile user) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayUnion([user.uid]),
    });
  }

  // Method to demote an admin
  Future<void> demoteFromAdmin(String groupId, UserProfile user) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayRemove([user.uid]),
    });
  }

  // Future<void> exitGroup(GroupProfile group) async {
  //   final currentUserId = _auth.currentUser!.uid;
  //   final currentUserEmail = _auth.currentUser!.email!.split('@')[0];

  //   await _sendSystemMessage(
  //     group.groupId,
  //     "$currentUserEmail left the group.",
  //   );
  //   await _firestore.collection('groups').doc(group.groupId).update({
  //     'members': FieldValue.arrayRemove([currentUserId]),
  //     'admins': FieldValue.arrayRemove([currentUserId]), // Also remove if admin
  //   });

  //   // Edge Case: If the last admin leaves, promote another member
  //   final updatedGroupDoc = await _firestore
  //       .collection('groups')
  //       .doc(group.groupId)
  //       .get();

  //   if (!updatedGroupDoc.exists) {
  //     return;
  //   }
  //   final updatedGroup = GroupProfile.fromDocument(updatedGroupDoc);

  //   if (updatedGroup.admins.isEmpty && updatedGroup.members.isNotEmpty) {
  //     // Promote the first member in the list to be the new admin
  //     final firstMemberDoc = await _firestore
  //         .collection('users')
  //         .doc(updatedGroup.members.first)
  //         .get();

  //     // Check if the user document exists before promoting
  //     if (firstMemberDoc.exists) {
  //       await promoteToAdmin(
  //         group.groupId,
  //         UserProfile.fromMap(firstMemberDoc.data()!),
  //       );
  //     }
  //   } else if (updatedGroup.members.isEmpty) {
  //     final messages = await _firestore
  //         .collection('groups')
  //         .doc(group.groupId)
  //         .collection('messages')
  //         .get();
  //     for (var doc in messages.docs) {
  //       await doc.reference.delete();
  //     }
  //     await _firestore.collection('groups').doc(group.groupId).delete();
  //   }
  // }
  // Method for a user to exit a group (Client-side atomic approach)
  Future<void> exitGroup(GroupProfile group) async {
    final currentUserId = _auth.currentUser!.uid;
    final currentUserEmail = _auth.currentUser!.email!.split('@')[0];

    // Get a batch writer to perform all operations atomically
    final batch = _firestore.batch();

    // 1. Prepare the system message to be added
    final messagesRef = _firestore
        .collection('groups')
        .doc(group.groupId)
        .collection('messages')
        .doc(); // Create a new doc reference for the system message

    final systemMessage = Message(
      senderId: 'system',
      senderEmail: 'system',
      receiverId: group.groupId,
      message: "$currentUserEmail left the group.",
      timestamp:
          Timestamp.now(), // Use a server-generated timestamp for accuracy
      type: 'system',
      reactions: {},
      readBy: {},
    );
    batch.set(messagesRef, systemMessage.toMap());

    // 2. Prepare the main group document update
    final groupRef = _firestore.collection('groups').doc(group.groupId);
    Map<String, dynamic> updates = {
      'members': FieldValue.arrayRemove([currentUserId]),
      'admins': FieldValue.arrayRemove([currentUserId]),
    };

    // 3. Handle the critical edge case: the last admin is leaving
    final bool isLastAdmin =
        group.admins.contains(currentUserId) && group.admins.length == 1;
    final bool willBeMemberless = group.members.length == 1;

    if (willBeMemberless) {
      // If this user is the last member, the group will be deleted later.
      // No need to promote a new admin.
    } else if (isLastAdmin) {
      // Find the next eligible member to promote to admin.
      // This must be someone other than the person who is leaving.
      String? newAdminId;
      for (String memberId in group.members) {
        if (memberId != currentUserId) {
          newAdminId = memberId;
          break; // Found the first available member, so we can stop looking.
        }
      }

      if (newAdminId != null) {
        // This is the key part for the security rule to work.
        // The 'admins' field is being completely overwritten with the new admin's ID.
        updates['admins'] = [newAdminId];
      }
    }

    // Add the updates to the batch
    batch.update(groupRef, updates);

    // 4. Commit all the changes in a single atomic operation
    await batch.commit();

    // 5. Handle post-commit cleanup, like deleting the group if it's now empty
    if (willBeMemberless) {
      // The group is now empty, so we can safely delete it.
      // This is a separate operation after the user has successfully left.
      // First, delete all messages in the subcollection.
      final messages = await _firestore
          .collection('groups')
          .doc(group.groupId)
          .collection('messages')
          .get();
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }
      // Then, delete the group document itself.
      await _firestore.collection('groups').doc(group.groupId).delete();
    }
  }

  Future<void> createGroup(
    String groupName,
    List<UserProfile> selectedContacts,
  ) async {
    final currentUser = _auth.currentUser!;
    final newGroupRef = _firestore.collection('groups').doc();

    List<String> memberIds = selectedContacts
        .map((contact) => contact.uid)
        .toList();
    memberIds.add(currentUser.uid);
    List<String> adminIds = [currentUser.uid];

    await newGroupRef.set({
      'groupId': newGroupRef.id,
      'groupName': groupName,
      'groupIcon': null,
      'createdBy': currentUser.uid,
      'members': memberIds,
      'lastMessage': 'Group created.',
      'lastMessageTimestamp': Timestamp.now(),

      'description': 'A new chat group!',
      'admins': adminIds,
    });
  }

  Stream<List<GroupProfile>> getGroupsStream() {
    final currentUser = _auth.currentUser!;

    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GroupProfile.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> sendGroupMessage({
    required String groupId,
    String? text,
    String? imageUrl,
  }) async {
    if (text == null && imageUrl == null) return;

    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: groupId,
      message: text ?? '',
      imageUrl: imageUrl,
      type: imageUrl != null ? 'image' : 'text',
      timestamp: timestamp,
      reactions: {},
      isReply: false,
      readBy: {},
    );

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(newMessage.toMap());

    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': text ?? "Sent an image",
      'lastMessageTimestamp': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
