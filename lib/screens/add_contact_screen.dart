import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _phoneController = TextEditingController();
  final _chatService = ChatService();
  final _authService = AuthService();
  bool _isLoading = false;
  UserProfile? _searchedUser;
  String _message = "Search for a user by their phone number.";

  Country selectedCountry = CountryParser.parseCountryCode(
    'IN',
  ); // Default to India

  void _searchUser() async {
    setState(() {
      _isLoading = true;
      _searchedUser = null;
      _message = "Searching...";
    });

    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullPhoneNumber = "+${selectedCountry.phoneCode}$phone";

    final result = await _chatService.searchUserByPhoneNumber(fullPhoneNumber);

    if (result != null) {
      if (result.uid == _authService.getCurrentUser()!.uid) {
        setState(() {
          _message = "You can't add yourself as a contact.";
        });
      } else {
        setState(() {
          _searchedUser = result;
        });
      }
    } else {
      setState(() {
        _message = "No user found with that phone number.";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _addContact() async {
    if (_searchedUser != null) {
      await _chatService.addContact(_searchedUser!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${_searchedUser!.email} has been added to your contacts.",
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Contact")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CustomTextField(
              controller: _phoneController,
              hintText: 'Phone number',
              prefixWidget: InkWell(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    onSelect: (value) =>
                        setState(() => selectedCountry = value),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Text(
                    "${selectedCountry.flagEmoji} +${selectedCountry.phoneCode}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text("Search User"),
                onPressed: _isLoading ? null : _searchUser,
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 30),
            _buildSearchResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResult() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchedUser != null) {
      return ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: _searchedUser!.photoURL != null
              ? CachedNetworkImageProvider(_searchedUser!.photoURL!)
              : null,
          child: _searchedUser!.photoURL == null
              ? Text(_searchedUser!.email[0].toUpperCase())
              : null,
        ),
        title: Text(_searchedUser!.email),
        subtitle: Text(_searchedUser!.uid),
        trailing: IconButton(
          icon: const Icon(Icons.person_add, color: Colors.green),
          onPressed: _addContact,
        ),
      );
    }

    return Center(child: Text(_message));
  }
}
