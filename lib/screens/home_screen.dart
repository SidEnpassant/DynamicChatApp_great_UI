import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamichatapp/services/presence_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:page_transition/page_transition.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_screen.dart';
import '../models/user_profile.dart';

// class HomeScreen extends StatelessWidget {
//   HomeScreen({super.key});

//   final ChatService _chatService = ChatService();
//   final AuthService _authService = AuthService();

//   @override
//   Widget build(BuildContext context) {
//     final currentUser = _authService.getCurrentUser()!;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chats'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.person),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 PageTransition(
//                   type: PageTransitionType.fade,
//                   child: const ProfileScreen(),
//                 ),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () => _authService.signOut(),
//           ),
//         ],
//       ),
//       body: StreamBuilder<List<Map<String, dynamic>>>(
//         stream: _chatService.getUsersStream(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return const Center(child: Text('Error'));
//           }
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           final users = snapshot.data!
//               .where((userData) => userData['uid'] != currentUser.uid)
//               .toList();

//           return ListView.builder(
//             itemCount: users.length,
//             itemBuilder: (context, index) {
//               final user = UserProfile.fromMap(users[index]);
//               return Card(
//                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//                 elevation: 2,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     radius: 25,
//                     backgroundColor: Colors.grey[300],
//                     backgroundImage: user.photoURL != null
//                         ? CachedNetworkImageProvider(user.photoURL!)
//                         : null,
//                     child: user.photoURL == null
//                         ? Text(
//                             user.email[0].toUpperCase(),
//                             style: const TextStyle(fontSize: 20),
//                           )
//                         : null,
//                   ),
//                   title: Text(user.email),
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       PageTransition(
//                         type: PageTransitionType.rightToLeftWithFade,
//                         child: ChatScreen(receiver: user),
//                       ),
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Add WidgetsBindingObserver to the state
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final PresenceService _presenceService =
      PresenceService(); // Create an instance

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set initial status to Online
    _presenceService.updateUserStatus('Online');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      _presenceService.updateUserStatus('Online');
    } else {
      // App is in the background or closed
      _presenceService.updateUserStatus('Offline');
    }
  }

  @override
  void dispose() {
    // Set status to offline one last time when the widget is removed
    _presenceService.updateUserStatus('Offline');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Helper function to format the last seen time
  String _formatLastSeen(Timestamp lastSeen) {
    final now = DateTime.now();
    final date = lastSeen.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return DateFormat('h:mm a').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        // ... (actions are the same)
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getUsersStream(),
        builder: (context, snapshot) {
          // ... (error and loading checks are the same)

          final users = snapshot.data!
              .where((userData) => userData['uid'] != currentUser.uid)
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = UserProfile.fromMap(users[index]);
              final isOnline = user.status == 'Online';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        // ... (CircleAvatar content is the same)
                      ),
                      // Add the green online indicator dot
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(user.email),
                  // Add the subtitle for last seen status
                  subtitle: Text(
                    isOnline
                        ? 'Online'
                        : 'Last seen: ${_formatLastSeen(user.lastSeen)}',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeftWithFade,
                        child: ChatScreen(receiver: user),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
