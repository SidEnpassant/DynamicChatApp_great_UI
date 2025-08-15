import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Associate user with OneSignal
      OneSignal.login(userCredential.user!.uid);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signUpAndLinkPhone({
    required String email,
    required String password,
    required PhoneAuthCredential credential,
  }) async {
    try {
      // Step 1: Create the user with email and password
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Step 2: Link the verified phone number to the new account
      await userCredential.user!.linkWithCredential(credential);

      // Step 3: Save user info to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'phoneNumber': credential.smsCode != null
            ? null
            : userCredential.user!.phoneNumber, // Store phone number
        'photoURL': null,
        'status': 'Online',
        'lastSeen': Timestamp.now(),
      });

      // Step 4: Associate with OneSignal
      OneSignal.login(userCredential.user!.uid);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle errors like 'email-already-in-use'
      throw Exception(e.message);
    }
  }

  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      OneSignal.login(userCredential.user!.uid);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if user is new
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // Save new user info to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.phoneNumber, // Or prompt for an email
          'photoURL': null,
          'status': 'Online',
          'lastSeen': Timestamp.now(),
        });
      }
      // Associate with OneSignal
      OneSignal.login(userCredential.user!.uid);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<UserCredential> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // UserCredential userCredential = await _auth
      //     .createUserWithEmailAndPassword(email: email, password: password);
      // Save user info in a separate document
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'photoURL': null,
        // Add these new fields for new users
        'status': 'Online', // Set to Online initially
        'lastSeen': Timestamp.now(),
      });
      OneSignal.login(userCredential.user!.uid);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Sign out
  Future<void> signOut() async {
    OneSignal.logout();
    return await _auth.signOut();
  }
}
