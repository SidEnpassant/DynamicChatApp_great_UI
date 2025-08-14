class UserProfile {
  final String uid;
  final String email;
  final String? photoURL;

  UserProfile({required this.uid, required this.email, this.photoURL});

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'photoURL': photoURL};
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      photoURL: map['photoURL'],
    );
  }
}
