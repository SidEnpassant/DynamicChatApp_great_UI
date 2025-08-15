// class UserProfile {
//   final String uid;
//   final String email;
//   final String? photoURL;

//   UserProfile({required this.uid, required this.email, this.photoURL});

//   Map<String, dynamic> toMap() {
//     return {'uid': uid, 'email': email, 'photoURL': photoURL};
//   }

//   factory UserProfile.fromMap(Map<String, dynamic> map) {
//     return UserProfile(
//       uid: map['uid'] ?? '',
//       email: map['email'] ?? '',
//       photoURL: map['photoURL'],
//     );
//   }
// }

// lib/models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? photoURL;
  final String status; // Add this
  final Timestamp lastSeen; // Add this

  UserProfile({
    required this.uid,
    required this.email,
    this.photoURL,
    required this.status, // Add this
    required this.lastSeen, // Add this
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
      // Provide default values if the fields don't exist yet
      status: map['status'] ?? 'Offline',
      lastSeen: map['lastSeen'] ?? Timestamp.now(),
    );
  }
}
