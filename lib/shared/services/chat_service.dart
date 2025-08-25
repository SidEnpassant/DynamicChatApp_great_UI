import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamichatapp/core/config/OneSignalAppCredentials.dart';
import 'package:dynamichatapp/shared/models/user_profile.dart';
import 'package:dynamichatapp/shared/models/group_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/message.dart';
import 'e2ee_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final E2EEService _e2eeService = E2EEService();

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

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> addContact(UserProfile contact) async {
    final currentUser = _auth.currentUser!;

    final currentUserDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
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
    List<String>? mentionedUserIds,
  }) async {
    if (text == null && imageUrl == null) return;

    String type = 'text';
    if (imageUrl != null) type = 'image';

    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    String? encryptedText = text;
    Map<String, dynamic>? e2eeData;

    if (text != null) {
      if (isGroup) {
        try {
          final groupE2EEEnabled =
              await _e2eeService.isGroupE2EEEnabled(receiverId);

          if (groupE2EEEnabled) {
            try {
              e2eeData =
                  await _e2eeService.encryptGroupMessage(text, receiverId);
              encryptedText = '[ENCRYPTED]';
              print('Group E2EE encryption successful');
            } catch (encryptError) {
              print('Group E2EE encryption failed: $encryptError');
              encryptedText = text;
              e2eeData = null;
            }
          } else {
            try {
              print('Auto-enabling E2EE for group...');
              final groupDoc =
                  await _firestore.collection('groups').doc(receiverId).get();
              final groupData = groupDoc.data();
              if (groupData != null) {
                final memberIds = List<String>.from(groupData['members'] ?? []);
                await _e2eeService.initializeGroupE2EE(receiverId, memberIds);
                print('Group E2EE auto-enabled');

                try {
                  e2eeData =
                      await _e2eeService.encryptGroupMessage(text, receiverId);
                  encryptedText = '[ENCRYPTED]';
                  print('Group E2EE encryption successful after auto-enable');
                } catch (encryptError) {
                  print(
                      'Group E2EE encryption failed after auto-enable: $encryptError');
                  encryptedText = text;
                  e2eeData = null;
                }
              } else {
                print('Group data not found - sending unencrypted');
                encryptedText = text;
              }
            } catch (autoEnableError) {
              print('Failed to auto-enable group E2EE: $autoEnableError');
              encryptedText = text;
            }
          }
        } catch (e) {
          print('Group E2EE check failed: $e - sending unencrypted message');
          encryptedText = text;
          e2eeData = null;
        }
      } else {
        try {
          final senderE2EEEnabled = await _e2eeService.isE2EEEnabled();
          final recipientE2EEEnabled =
              await _e2eeService.getUserE2EEStatus(receiverId);

          print(
              'E2EE Status - Sender: $senderE2EEEnabled, Recipient: $recipientE2EEEnabled');

          if (senderE2EEEnabled && recipientE2EEEnabled) {
            try {
              e2eeData = await _e2eeService.encryptMessage(text, receiverId);
              encryptedText = '[ENCRYPTED]';
              print('E2EE encryption successful');
            } catch (encryptError) {
              print('E2EE encryption failed: $encryptError');
              encryptedText = text;
              e2eeData = null;
            }
          } else {
            if (!senderE2EEEnabled) {
              try {
                print('Auto-enabling E2EE for sender...');
                await _e2eeService.initializeE2EE();
                print('E2EE auto-enabled for sender');

                final updatedRecipientE2EEEnabled =
                    await _e2eeService.getUserE2EEStatus(receiverId);

                if (updatedRecipientE2EEEnabled) {
                  try {
                    e2eeData =
                        await _e2eeService.encryptMessage(text, receiverId);
                    encryptedText = '[ENCRYPTED]';
                    print('E2EE encryption successful after auto-enable');
                  } catch (encryptError) {
                    print(
                        'E2EE encryption failed after auto-enable: $encryptError');
                    encryptedText = text;
                    e2eeData = null;
                  }
                } else {
                  print('Recipient E2EE not enabled - sending unencrypted');
                  encryptedText = text;
                }
              } catch (autoEnableError) {
                print('Failed to auto-enable E2EE: $autoEnableError');
                encryptedText = text;
              }
            } else {
              print('E2EE not enabled for both users - sending unencrypted');
              encryptedText = text;
            }
          }
        } catch (e) {
          print('E2EE check failed: $e - sending unencrypted message');
          encryptedText = text;
          e2eeData = null;
        }
      }
    }

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      senderName: userData['email'].toString().split('@')[0],
      senderPhotoURL: userData['photoURL'],
      receiverId: receiverId,
      message: encryptedText ?? '',
      imageUrl: imageUrl,
      type: imageUrl != null ? 'image' : 'text',
      timestamp: timestamp,
      reactions: {},
      isReply: repliedToMessage != null,
      replyingToMessage: repliedToMessage?.message,
      replyingToSender: repliedToMessage?.senderEmail,
      readBy: {currentUserId: Timestamp.now()},
      mentionedUsers: mentionedUserIds ?? [],
    );

    if (isGroup) {
      final messageData = newMessage.toMap();
      if (e2eeData != null) {
        messageData['e2eeData'] = e2eeData;
        messageData['encrypted'] = true;
      }

      await _firestore
          .collection('groups')
          .doc(receiverId)
          .collection('messages')
          .add(messageData);

      if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) {
        await _sendMentionNotification(
          groupName:
              (await _firestore.collection('groups').doc(receiverId).get())
                  .data()!['groupName'],
          mentionedUserIds: mentionedUserIds,
          senderName: userData['email'].toString().split('@')[0],
          message: text ?? "Sent an image.",
        );
      }
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      String chatRoomId = ids.join('_');

      final messageData = newMessage.toMap();
      if (e2eeData != null) {
        messageData['e2eeData'] = e2eeData;
        messageData['encrypted'] = true;
      }

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      await _sendOneSignalNotification(
        receiverId: receiverId,
        senderEmail: currentUserEmail,
        message: text,
        imageUrl: imageUrl,
      );
    }
  }

  Future<void> _sendMentionNotification({
    required String groupName,
    required List<String> mentionedUserIds,
    required String senderName,
    required String message,
  }) async {
    print("Sending mention notification to: $mentionedUserIds");
    print("Message: '$senderName mentioned you in $groupName: $message'");
  }

  Future<void> togglePersonalMessageReaction(
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

  Future<void> toggleGroupMessageReaction(
    String groupId,
    String messageId,
    String emoji,
  ) async {
    final currentUserId = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('groups')
        .doc(groupId)
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

    final String notificationContent =
        imageUrl != null ? "Sent you an image." : message!;

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

  Future<String> decryptMessageIfNeeded(
      Map<String, dynamic> messageData) async {
    try {
      print('DEBUG: decryptMessageIfNeeded called');
      print('DEBUG: messageData keys: ${messageData.keys.toList()}');
      print('DEBUG: encrypted field: ${messageData['encrypted']}');
      print('DEBUG: e2eeData field: ${messageData['e2eeData']}');

      if (messageData['encrypted'] == true && messageData['e2eeData'] != null) {
        print('DEBUG: Message is encrypted, proceeding with decryption');

        final e2eeData = messageData['e2eeData'] as Map<String, dynamic>;

        print('DEBUG: e2eeData keys: ${e2eeData.keys.toList()}');
        print('DEBUG: e2eeData values: ${e2eeData.values.toList()}');

        final isGroupMessage = e2eeData['isGroupMessage'] == true;
        print('DEBUG: isGroupMessage: $isGroupMessage');

        if (isGroupMessage) {
          print('DEBUG: Processing as GROUP message');
          try {
            final result = await _e2eeService.decryptGroupMessage(e2eeData);
            print('DEBUG: Group decryption successful: $result');
            return result;
          } catch (e) {
            print('DEBUG: Group E2EE decryption failed: $e');
            return messageData['message'] ?? '[Group decryption failed]';
          }
        } else {
          print('DEBUG: Processing as PERSONAL message');

          final requiredFields = [
            'encryptedMessage',
            'iv',
            'encryptedSessionKey',
            'sessionKeyIV',
            'signature',
            'recipientPublicKey'
          ];

          for (final field in requiredFields) {
            if (e2eeData[field] == null) {
              print('DEBUG: Missing or null field: $field');
              return messageData['message'] ??
                  '[Decryption failed - missing field: $field]';
            }
          }

          final cryptoData = <String, String>{
            'encryptedMessage': e2eeData['encryptedMessage']!.toString(),
            'iv': e2eeData['iv']!.toString(),
            'encryptedSessionKey': e2eeData['encryptedSessionKey']!.toString(),
            'sessionKeyIV': e2eeData['sessionKeyIV']!.toString(),
            'signature': e2eeData['signature']!.toString(),
            'recipientPublicKey': e2eeData['recipientPublicKey']!.toString(),
          };

          return await _e2eeService.decryptMessage(cryptoData);
        }
      } else {
        print('DEBUG: Message is NOT encrypted or missing e2eeData');
        print('DEBUG: encrypted: ${messageData['encrypted']}');
        print('DEBUG: e2eeData: ${messageData['e2eeData']}');
      }

      return messageData['message'] ?? '';
    } catch (e) {
      print('DEBUG: E2EE decryption failed with error: $e');
      return messageData['message'] ?? '[Decryption failed]';
    }
  }

  Stream<List<Message>> getMessagesStream(
      String chatRoomId, bool isGroup) async* {
    final currentUserId = _auth.currentUser!.uid;

    final messagesQuery = isGroup
        ? _firestore
            .collection('groups')
            .doc(chatRoomId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
        : _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .orderBy('timestamp', descending: false);

    await for (final snapshot in messagesQuery.snapshots()) {
      final messages = <Message>[];

      for (final doc in snapshot.docs) {
        final messageData = doc.data();
        messageData['id'] = doc.id;

        final decryptedMessage = await decryptMessageIfNeeded(messageData);
        messageData['message'] = decryptedMessage;

        messages.add(Message.fromMap(messageData, doc.id));
      }

      yield messages;
    }
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

  Future<void> markGroupMessageAsRead(String groupId, String messageId) async {
    final currentUserId = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

    try {
      await messageRef.update({'readBy.$currentUserId': Timestamp.now()});
    } on FirebaseException catch (e) {
      print("Group read receipt error: ${e.message}");
    }
  }

  Future<void> pinMessage(GroupProfile group, Message message) async {
    final pinnedMessageData = {
      'messageId': message.id,
      'message': message.message,
      'senderName': message.senderName ?? message.senderEmail.split('@')[0],
      'type': message.type,
    };
    await _firestore.collection('groups').doc(group.groupId).update({
      'pinnedMessage': pinnedMessageData,
    });
  }

  Future<void> unpinMessage(GroupProfile group) async {
    await _firestore.collection('groups').doc(group.groupId).update({
      'pinnedMessage': FieldValue.delete(),
    });
  }

  Future<void> markPersonalMessageAsRead(
    String chatRoomId,
    String messageId,
  ) async {
    final currentUserId = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId);

    try {
      await messageRef.update({'readBy.$currentUserId': Timestamp.now()});
    } on FirebaseException catch (e) {
      print("Personal read receipt error on path: ${messageRef.path}");
      print("Error: ${e.message}");
    }
  }

  Future<void> _sendSystemMessage(String groupId, String text) async {
    final Message systemMessage = Message(
      senderId: 'system',
      senderEmail: 'system',
      receiverId: groupId,
      message: text,
      timestamp: Timestamp.now(),
      type: 'system',
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

    try {
      final isGroupE2EEEnabled = await _e2eeService.isGroupE2EEEnabled(groupId);
      if (isGroupE2EEEnabled) {
        for (final member in newMembers) {
          try {
            await _e2eeService.addMemberToGroupE2EE(groupId, member.uid);
          } catch (e) {
            print(
                'Warning: Could not add member ${member.uid} to group E2EE: $e');
          }
        }
      }
    } catch (e) {
      print('Warning: Group E2EE member addition failed: $e');
    }

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
      ]),
    });

    try {
      final isGroupE2EEEnabled = await _e2eeService.isGroupE2EEEnabled(groupId);
      if (isGroupE2EEEnabled) {
        await _e2eeService.removeMemberFromGroupE2EE(
            groupId, memberToRemove.uid);
      }
    } catch (e) {
      print('Warning: Group E2EE member removal failed: $e');
    }

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

  Future<void> demoteFromAdmin(String groupId, UserProfile user) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayRemove([user.uid]),
    });
  }

  Future<void> exitGroup(GroupProfile group) async {
    final currentUserId = _auth.currentUser!.uid;
    final currentUserEmail = _auth.currentUser!.email!.split('@')[0];

    final batch = _firestore.batch();

    final messagesRef = _firestore
        .collection('groups')
        .doc(group.groupId)
        .collection('messages')
        .doc();

    final systemMessage = Message(
      senderId: 'system',
      senderEmail: 'system',
      receiverId: group.groupId,
      message: "$currentUserEmail left the group.",
      timestamp: Timestamp.now(),
      type: 'system',
      reactions: {},
      readBy: {},
    );
    batch.set(messagesRef, systemMessage.toMap());

    final groupRef = _firestore.collection('groups').doc(group.groupId);
    Map<String, dynamic> updates = {
      'members': FieldValue.arrayRemove([currentUserId]),
      'admins': FieldValue.arrayRemove([currentUserId]),
    };

    final bool isLastAdmin =
        group.admins.contains(currentUserId) && group.admins.length == 1;
    final bool willBeMemberless = group.members.length == 1;

    if (willBeMemberless) {
    } else if (isLastAdmin) {
      String? newAdminId;
      for (String memberId in group.members) {
        if (memberId != currentUserId) {
          newAdminId = memberId;
          break;
        }
      }

      if (newAdminId != null) {
        updates['admins'] = [newAdminId];
      }
    }

    batch.update(groupRef, updates);

    await batch.commit();

    if (willBeMemberless) {
      final messages = await _firestore
          .collection('groups')
          .doc(group.groupId)
          .collection('messages')
          .get();
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }
      await _firestore.collection('groups').doc(group.groupId).delete();
    }
  }

  Future<void> createGroup(
    String groupName,
    List<UserProfile> selectedContacts,
  ) async {
    final currentUser = _auth.currentUser!;
    final newGroupRef = _firestore.collection('groups').doc();

    List<String> memberIds =
        selectedContacts.map((contact) => contact.uid).toList();
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

    try {
      bool allMembersHaveE2EE = true;
      for (final memberId in memberIds) {
        final hasE2EE = await _e2eeService.getUserE2EEStatus(memberId);
        if (!hasE2EE) {
          allMembersHaveE2EE = false;
          break;
        }
      }

      if (allMembersHaveE2EE) {
        await _e2eeService.initializeGroupE2EE(newGroupRef.id, memberIds);
        print('Group E2EE initialized for new group: ${newGroupRef.id}');
      } else {
        print('Not all members have E2EE enabled - group E2EE not initialized');
      }
    } catch (e) {
      print('Warning: Failed to initialize group E2EE: $e');
    }
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

    String? encryptedText = text;
    Map<String, dynamic>? e2eeData;

    if (text != null) {
      try {
        final groupE2EEEnabled = await _e2eeService.isGroupE2EEEnabled(groupId);

        if (groupE2EEEnabled) {
          try {
            e2eeData = await _e2eeService.encryptGroupMessage(text, groupId);
            encryptedText = '[ENCRYPTED]'; // Placeholder for encrypted content
            print('Group E2EE encryption successful');
          } catch (encryptError) {
            print('Group E2EE encryption failed: $encryptError');
            encryptedText = text;
            e2eeData = null;
          }
        } else {
          try {
            print('Auto-enabling E2EE for group...');
            final groupDoc =
                await _firestore.collection('groups').doc(groupId).get();
            final groupData = groupDoc.data();
            if (groupData != null) {
              final memberIds = List<String>.from(groupData['members'] ?? []);
              await _e2eeService.initializeGroupE2EE(groupId, memberIds);
              print('Group E2EE auto-enabled');
              try {
                e2eeData =
                    await _e2eeService.encryptGroupMessage(text, groupId);
                encryptedText = '[ENCRYPTED]';
                print('Group E2EE encryption successful after auto-enable');
              } catch (encryptError) {
                print(
                    'Group E2EE encryption failed after auto-enable: $encryptError');
                encryptedText = text;
                e2eeData = null;
              }
            } else {
              print('Group data not found - sending unencrypted');
              encryptedText = text;
            }
          } catch (autoEnableError) {
            print('Failed to auto-enable group E2EE: $autoEnableError');
            encryptedText = text;
          }
        }
      } catch (e) {
        print('Group E2EE check failed: $e - sending unencrypted message');
        encryptedText = text;
        e2eeData = null;
      }
    }

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: groupId,
      message: encryptedText ?? '',
      imageUrl: imageUrl,
      type: imageUrl != null ? 'image' : 'text',
      timestamp: timestamp,
      reactions: {},
      isReply: false,
      readBy: {},
    );

    final messageData = newMessage.toMap();
    if (e2eeData != null) {
      messageData['e2eeData'] = e2eeData;
      messageData['encrypted'] = true;
    }

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(messageData);

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

  Stream<List<Message>> getGroupMessagesStreamWithDecryption(
      String groupId) async* {
    final messagesQuery = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    await for (final snapshot in messagesQuery.snapshots()) {
      final messages = <Message>[];

      for (final doc in snapshot.docs) {
        final messageData = doc.data();
        messageData['id'] = doc.id;

        final decryptedMessage = await decryptMessageIfNeeded(messageData);
        messageData['message'] = decryptedMessage;

        messages.add(Message.fromMap(messageData, doc.id));
      }

      yield messages;
    }
  }
}
