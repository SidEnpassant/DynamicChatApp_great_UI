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

  // Future<void> sendMessage(
  //   String receiverId, {
  //   String? text,
  //   String? imageUrl,
  // }) async {
  //   if (text == null && imageUrl == null) return; // Can't send an empty message

  //   final String currentUserId = _auth.currentUser!.uid;
  //   final String currentUserEmail = _auth.currentUser!.email!;
  //   final Timestamp timestamp = Timestamp.now();

  //   Message newMessage = Message(
  //     senderId: currentUserId,
  //     senderEmail: currentUserEmail,
  //     receiverId: receiverId,
  //     message: text ?? '', // Use text or an empty string
  //     imageUrl: imageUrl,
  //     type: imageUrl != null ? 'image' : 'text', // Set the type
  //     timestamp: timestamp,
  //   );

  //   List<String> ids = [currentUserId, receiverId];
  //   ids.sort();
  //   String chatRoomId = ids.join('_');

  //   await _firestore
  //       .collection('chat_rooms')
  //       .doc(chatRoomId)
  //       .collection('messages')
  //       .add(newMessage.toMap());
  //   final String currentUserEmail = _auth.currentUser!.email!;
  //   await _sendOneSignalNotification(
  //     receiverId: receiverId,
  //     senderEmail: currentUserEmail,
  //     message: text,
  //     imageUrl: imageUrl,
  //   );
  // }

  Future<void> sendMessage(
    String receiverId, {
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
      receiverId: receiverId,
      message: text ?? '',
      imageUrl: imageUrl,
      type: imageUrl != null ? 'image' : 'text',
      timestamp: timestamp,
    );

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage.toMap());

    // After saving the message, send the notification using the variable we already have.
    // The duplicate declaration has been removed from here.
    await _sendOneSignalNotification(
      receiverId: receiverId,
      senderEmail: currentUserEmail,
      message: text,
      imageUrl: imageUrl,
    );
  }

  Future<void> _sendOneSignalNotification({
    required String receiverId,
    required String senderEmail,
    String? message,
    String? imageUrl,
  }) async {
    // --- IMPORTANT: Replace with your actual keys ---
    const String oneSignalAppId = OnesignalappCredentials.OneSignalId;
    const String oneSignalRestApiKey = OnesignalappCredentials.OneSignaAPI_KEY;
    // ---------------------------------------------

    // The content of the notification
    final String notificationContent = imageUrl != null
        ? "Sent you an image."
        : message!;

    final body = {
      "app_id": oneSignalAppId,
      // Target the specific user by their external_user_id (which we set as their Firebase UID)
      "include_external_user_ids": [receiverId],
      "headings": {"en": "New message from $senderEmail"},
      "contents": {"en": notificationContent},
      // This helps group notifications on the device
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

  // Get messages
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
    await chatRoomRef.set(
      {
        'typingStatus': {userId: isTyping},
      },
      SetOptions(merge: true), // Merge to avoid overwriting the whole document
    );
  }

  Stream<DocumentSnapshot> getChatRoomStream(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }
}
