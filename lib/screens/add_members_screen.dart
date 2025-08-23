import 'package:dynamichatapp/models/group_profile.dart';
import 'package:dynamichatapp/models/user_profile.dart';
import 'package:dynamichatapp/services/chat_service.dart';
import 'package:flutter/material.dart';

class AddMembersScreen extends StatefulWidget {
  final GroupProfile group;
  const AddMembersScreen({super.key, required this.group});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final ChatService _chatService = ChatService();
  final List<UserProfile> _selectedContacts = [];
  bool _isLoading = false;

  void _toggleContactSelection(UserProfile contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  void _addMembers() async {
    if (_selectedContacts.isEmpty) return;

    setState(() => _isLoading = true);
    await _chatService.addMembersToGroup(
      widget.group.groupId,
      _selectedContacts,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Members")),
      body: StreamBuilder<List<UserProfile>>(
        // Get all contacts
        stream: _chatService.getContactsProfilesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final availableContacts = snapshot.data!
              .where((contact) => !widget.group.members.contains(contact.uid))
              .toList();

          if (availableContacts.isEmpty) {
            return const Center(
              child: Text("All your contacts are already in the group."),
            );
          }

          return ListView.builder(
            itemCount: availableContacts.length,
            itemBuilder: (context, index) {
              final contact = availableContacts[index];
              final isSelected = _selectedContacts.contains(contact);
              return ListTile(
                title: Text(contact.email),
                leading: CircleAvatar(
                  // ... your avatar UI
                ),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleContactSelection(contact),
                ),
                onTap: () => _toggleContactSelection(contact),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _selectedContacts.isEmpty ? null : _addMembers,
        icon: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.check),
        label: const Text("Add Members"),
      ),
    );
  }
}
