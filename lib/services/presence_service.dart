import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void updateUserStatus(String status) {
    final user = _auth.currentUser;
    if (user != null) {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      if (status == 'Online') {
        userDocRef.update({'status': 'Online'});
      } else {
        userDocRef.update({'status': 'Offline', 'lastSeen': Timestamp.now()});
      }
    }
  }
}
