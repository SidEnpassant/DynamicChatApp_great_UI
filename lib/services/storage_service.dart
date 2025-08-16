// import 'dart:io';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class StorageService {
//   final FirebaseStorage _storage = FirebaseStorage.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // Future<String?> uploadProfilePicture(XFile image) async {
//   //   try {
//   //     final user = _auth.currentUser;
//   //     if (user == null) return null;

//   //     final ref = _storage
//   //         .ref()
//   //         .child('profile_pictures')
//   //         .child('${user.uid}.jpg');
//   //     await ref.putFile(File(image.path));
//   //     final url = await ref.getDownloadURL();

//   //     // Update user document in Firestore
//   //     await _firestore.collection('users').doc(user.uid).update({
//   //       'photoURL': url,
//   //     });
//   //     return url;
//   //   } catch (e) {
//   //     print('Error uploading profile picture: $e');
//   //     return null;
//   //   }
//   // }

//   // In lib/services/storage_service.dart
//   Future<String?> uploadProfilePicture(XFile image) async {
//     try {
//       final user = _auth.currentUser;
//       if (user == null) return null;

//       // --- THESE LINES ARE CRITICAL FOR DEBUGGING ---
//       print('VERIFYING UPLOAD: User UID is ${user.uid}');
//       final ref = _storage
//           .ref()
//           .child('profile_pictures')
//           .child('${user.uid}.jpg');
//       print('VERIFYING UPLOAD: Attempting to write to path: ${ref.fullPath}');
//       // ------------------------------------------

//       await ref.putFile(File(image.path));
//       final url = await ref.getDownloadURL();

//       await _firestore.collection('users').doc(user.uid).update({
//         'photoURL': url,
//       });
//       return url;
//     } catch (e) {
//       print('Error uploading profile picture: $e');
//       return null;
//     }
//   }
// }

// In lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadProfilePicture(XFile image) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final ref = _storage
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      // --- THIS IS THE CRUCIAL PART ---
      // 1. Update the user's profile in the Authentication service
      await user.updatePhotoURL(url);

      // 2. Update the user's document in the Firestore database
      await _firestore.collection('users').doc(user.uid).update({
        'photoURL': url,
      });

      return url;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  Future<String?> uploadChatImage(XFile image, String chatRoomId) async {
    try {
      // Create a unique filename for each image
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage
          .ref()
          .child('chat_images')
          .child(chatRoomId)
          .child('$fileName.jpg');

      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading chat image: $e');
      return null;
    }
  }

  Future<String?> uploadAudioMessage(String filePath, String chatRoomId) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage
          .ref()
          .child('audio_messages')
          .child(chatRoomId)
          .child('$fileName.m4a');

      await ref.putFile(File(filePath));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading audio message: $e');
      return null;
    }
  }
}
