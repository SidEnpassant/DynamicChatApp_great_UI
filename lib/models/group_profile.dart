import 'package:cloud_firestore/cloud_firestore.dart';

class GroupProfile {
  final String groupId;
  final String groupName;
  final String? groupIcon;
  final String createdBy;
  final List<String> members;
  final String? lastMessage;
  final Timestamp? lastMessageTimestamp;

  GroupProfile({
    required this.groupId,
    required this.groupName,
    this.groupIcon,
    required this.createdBy,
    required this.members,
    this.lastMessage,
    this.lastMessageTimestamp,
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
    );
  }

  get name => null;
}
