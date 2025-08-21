import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final String? imageUrl;
  final String type;
  final Map<String, List<String>> reactions;

  final bool isReply;
  final String? replyingToMessage;
  final String? replyingToSender;

  Message({
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.imageUrl,
    required this.type,
    required this.reactions,

    this.isReply = false,
    this.replyingToMessage,
    this.replyingToSender,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'type': type,
      'reactions': reactions,

      'isReply': isReply,
      'replyingToMessage': replyingToMessage,
      'replyingToSender': replyingToSender,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    final reactionsData = map['reactions'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> reactions = {};
    reactionsData.forEach((key, value) {
      if (value is List) {
        reactions[key] = List<String>.from(value);
      }
    });
    return Message(
      senderId: map['senderId'],
      senderEmail: map['senderEmail'],
      receiverId: map['receiverId'],
      message: map['message'],
      timestamp: map['timestamp'],
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'text',
      reactions: reactions,
      isReply: map['isReply'] ?? false,
      replyingToMessage: map['replyingToMessage'],
      replyingToSender: map['replyingToSender'],
    );
  }
}
