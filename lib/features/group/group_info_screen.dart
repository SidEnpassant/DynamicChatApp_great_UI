import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamichatapp/shared/models/group_profile.dart';
import 'package:dynamichatapp/shared/models/user_profile.dart';
import 'package:dynamichatapp/features/group/add_members_screen.dart';
import 'package:dynamichatapp/features/chat/home_screen.dart';
import 'package:dynamichatapp/shared/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupProfile group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  void _showEditGroupDialog(BuildContext context, GroupProfile group) {
    final nameController = TextEditingController(text: group.groupName);
    final descriptionController = TextEditingController(
      text: group.description,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _chatService.updateGroupDetails(
                group.groupId,
                nameController.text,
                descriptionController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadIcon() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      await _chatService.updateGroupIcon(widget.group.groupId, image);
    }
  }

  void _handleMemberAction(
    String action,
    GroupProfile group,
    UserProfile user,
  ) {
    switch (action) {
      case 'remove':
        _chatService.removeMemberFromGroup(group.groupId, user);
        break;
      case 'promote':
        _chatService.promoteToAdmin(group.groupId, user);
        break;
      case 'demote':
        _chatService.demoteFromAdmin(group.groupId, user);
        break;
    }
  }

  void _handleExitGroup(BuildContext context, GroupProfile group) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _chatService.exitGroup(group);
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final updatedGroup = GroupProfile.fromDocument(snapshot.data!);
        final bool isAdmin = updatedGroup.admins.contains(
          _auth.currentUser!.uid,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Group Information'),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditGroupDialog(context, updatedGroup),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildGroupHeader(context, updatedGroup, isAdmin),
                const SizedBox(height: 10),
                const Divider(),
                _buildMemberList(context, updatedGroup, isAdmin),
                const Divider(),
                _buildExitGroupButton(context, updatedGroup),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    GroupProfile group,
    bool isAdmin,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: group.groupIcon != null
                    ? CachedNetworkImageProvider(group.groupIcon!)
                    : null,
                child: group.groupIcon == null
                    ? const Icon(Icons.group, size: 60)
                    : null,
              ),
              if (isAdmin)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _pickAndUploadIcon,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            group.groupName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            group.description ?? "No description",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(
    BuildContext context,
    GroupProfile group,
    bool isAdmin,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            '${group.members.length} Members',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Add Members'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddMembersScreen(group: group),
                ),
              );
            },
          ),
        StreamBuilder<QuerySnapshot>(
          stream: _chatService.getUsersByIdsStream(group.members),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final memberDocs = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: memberDocs.length,
              itemBuilder: (context, index) {
                final userDoc = memberDocs[index];
                final userProfile = UserProfile.fromMap(
                  userDoc.data() as Map<String, dynamic>,
                );
                final bool isMemberAdmin = group.admins.contains(
                  userProfile.uid,
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userProfile.photoURL != null
                        ? CachedNetworkImageProvider(userProfile.photoURL!)
                        : null,
                    child: userProfile.photoURL == null
                        ? Text(userProfile.email[0].toUpperCase())
                        : null,
                  ),
                  title: Text(userProfile.email.split('@')[0]),
                  subtitle: isMemberAdmin
                      ? const Text(
                          "Admin",
                          style: TextStyle(color: Colors.green),
                        )
                      : null,
                  trailing:
                      (isAdmin && userProfile.uid != _auth.currentUser!.uid)
                      ? PopupMenuButton<String>(
                          onSelected: (value) =>
                              _handleMemberAction(value, group, userProfile),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove User'),
                            ),
                            if (isMemberAdmin)
                              const PopupMenuItem(
                                value: 'demote',
                                child: Text('Demote from Admin'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'promote',
                                child: Text('Promote to Admin'),
                              ),
                          ],
                        )
                      : null,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildExitGroupButton(BuildContext context, GroupProfile group) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListTile(
        leading: const Icon(Icons.exit_to_app, color: Colors.red),
        title: const Text('Exit Group', style: TextStyle(color: Colors.red)),
        onTap: () => _handleExitGroup(context, group),
      ),
    );
  }
}
