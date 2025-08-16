import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamichatapp/OneSignalAppCredentials.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get stream of users
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
    String? audioUrl,
    Message? repliedToMessage,
  }) async {
    if (text == null && imageUrl == null && audioUrl == null) return;

    String type = 'text';
    if (imageUrl != null) type = 'image';
    if (audioUrl != null) type = 'audio';

    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: text ?? '',
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      type: imageUrl != null ? 'image' : 'text',
      timestamp: timestamp,
      reactions: {},

      isReply: repliedToMessage != null,
      replyingToMessage: repliedToMessage?.message,
      replyingToSender: repliedToMessage?.senderEmail,
    );

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
}
