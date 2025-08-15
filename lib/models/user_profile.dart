import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? photoURL;
  final String status;
  final Timestamp lastSeen;

  UserProfile({
    required this.uid,
    required this.email,
    this.photoURL,
    required this.status,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'photoURL': photoURL,
      'status': status,
      'lastSeen': lastSeen,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      photoURL: map['photoURL'],
      status: map['status'] ?? 'Offline',
      lastSeen: map['lastSeen'] ?? Timestamp.now(),
    );
  }
}
