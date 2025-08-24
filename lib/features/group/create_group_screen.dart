import 'package:flutter/material.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/widgets/custom_textfield.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _chatService = ChatService();
  final List<UserProfile> _selectedContacts = [];

  void _toggleContactSelection(UserProfile contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || _selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please provide a group name and select at least one member.",
          ),
        ),
      );
      return;
    }

    await _chatService.createGroup(
      _groupNameController.text.trim(),
      _selectedContacts,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Group")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomTextField(
              controller: _groupNameController,
              hintText: "Enter Group Name",
            ),
          ),
          const Text(
            "Select Members",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: _chatService.getContactsProfilesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final contacts = snapshot.data!;
                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.check),
        label: const Text("Create Group"),
      ),
    );
  }
}
