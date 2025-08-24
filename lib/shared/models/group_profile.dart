import 'package:cloud_firestore/cloud_firestore.dart';

class GroupProfile {
  final String groupId;
  final String groupName;
  final String? groupIcon;
  final String createdBy;
  final List<String> members;
  final String? lastMessage;
  final Timestamp? lastMessageTimestamp;

  final String? description;
  final List<String> admins;
  final Map<String, dynamic>? pinnedMessage;

  GroupProfile({
    required this.groupId,
    required this.groupName,
    this.groupIcon,
    required this.createdBy,
    required this.members,
    this.lastMessage,
    this.lastMessageTimestamp,

    this.description,
    required this.admins,

    this.pinnedMessage,
  });

  factory GroupProfile.fromMap(Map<String, dynamic> map) {
    return GroupProfile(
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      groupIcon: map['groupIcon'],
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageTimestamp: map['lastMessageTimestamp'],

      description: map['description'],
      admins: List<String>.from(map['admins'] ?? []),
      pinnedMessage: map['pinnedMessage'] as Map<String, dynamic>?,
    );
  }
  factory GroupProfile.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupProfile.fromMap(data);
  }

  //get name => null;
}
