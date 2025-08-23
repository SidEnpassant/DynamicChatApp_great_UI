// import 'dart:async';
// import 'package:dynamichatapp/models/group_profile.dart';
// import 'package:dynamichatapp/models/message.dart';
// import 'package:dynamichatapp/screens/group_info_screen.dart';
// import 'package:dynamichatapp/services/storage_service.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import '../services/auth_service.dart';
// import '../services/chat_service.dart';
// import '../models/user_profile.dart';
// import '../widgets/chat_bubble.dart';

// class ChatScreen extends StatefulWidget {
//   final UserProfile? receiver;
//   final GroupProfile? group;
//   final bool isGroupChat;

//   const ChatScreen({
//     super.key,
//     this.receiver,
//     this.group,
//     this.isGroupChat = false,
//   });

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
//   final TextEditingController _messageController = TextEditingController();
//   final ChatService _chatService = ChatService();
//   final AuthService _authService = AuthService();
//   final StorageService _storageService = StorageService();
//   final ImagePicker _picker = ImagePicker();
//   final ScrollController _scrollController = ScrollController();

//   Timer? _typingTimer;
//   late String _chatEntityId;
//   Message? _replyingToMessage;

//   @override
//   void initState() {
//     super.initState();

//     if (widget.isGroupChat) {
//       _chatEntityId = widget.group!.groupId;
//     } else {
//       List<String> ids = [
//         _authService.getCurrentUser()!.uid,
//         widget.receiver!.uid,
//       ];
//       ids.sort();
//       _chatEntityId = ids.join('_');
//     }

//     _messageController.addListener(_onTyping);
//   }

//   @override
//   void dispose() {
//     _messageController.removeListener(_onTyping);
//     _scrollController.dispose();
//     _typingTimer?.cancel();
//     if (!widget.isGroupChat) {
//       _chatService.updateTypingStatus(
//         _chatEntityId,
//         _authService.getCurrentUser()!.uid,
//         false,
//       );
//     }
//     super.dispose();
//   }

//   void _onTyping() {
//     setState(() {});
//     if (widget.isGroupChat) return;
//     final currentUser = _authService.getCurrentUser()!;
//     _typingTimer?.cancel();
//     if (_messageController.text.isNotEmpty) {
//       _chatService.updateTypingStatus(_chatEntityId, currentUser.uid, true);
//     }
//     _typingTimer = Timer(const Duration(seconds: 2), () {
//       _chatService.updateTypingStatus(_chatEntityId, currentUser.uid, false);
//     });
//   }

//   void _markVisibleMessagesAsRead(List<QueryDocumentSnapshot> messages) {
//     for (var doc in messages) {
//       final message = Message.fromMap(doc.data() as Map<String, dynamic>);
//       final isReadByCurrentUser = message.readBy.containsKey(
//         _authService.getCurrentUser()!.uid,
//       );

//       if (message.senderId != _authService.getCurrentUser()!.uid &&
//           !isReadByCurrentUser) {
//         _chatService.markMessageAsRead(
//           _chatEntityId,
//           doc.id,
//           widget.isGroupChat,
//         );
//       }
//     }
//   }

//   void _sendMessage() async {
//     if (_messageController.text.isNotEmpty) {
//       final receiverId = widget.isGroupChat
//           ? widget.group!.groupId
//           : widget.receiver!.uid;
//       await _chatService.sendMessage(
//         receiverId,
//         isGroup: widget.isGroupChat,
//         text: _messageController.text,
//         repliedToMessage: _replyingToMessage,
//       );
//       _messageController.clear();
//       setState(() {
//         _replyingToMessage = null;
//       });
//     }
//   }

//   void _sendImage() async {
//     final XFile? image = await _picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 70,
//     );
//     if (image != null) {
//       final imageUrl = await _storageService.uploadChatImage(
//         image,
//         _chatEntityId,
//       );
//       if (imageUrl != null) {
//         final receiverId = widget.isGroupChat
//             ? widget.group!.groupId
//             : widget.receiver!.uid;
//         await _chatService.sendMessage(
//           receiverId,
//           isGroup: widget.isGroupChat,
//           imageUrl: imageUrl,
//           repliedToMessage: _replyingToMessage,
//         );
//         setState(() {
//           _replyingToMessage = null;
//         });
//       }
//     }
//   }

//   void _showSeenByDialog(BuildContext context, Message message) {
//     final readByUserIds = message.readBy.keys.toList();

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return DraggableScrollableSheet(
//           expand: false,
//           initialChildSize: 0.5,
//           minChildSize: 0.3,
//           maxChildSize: 0.8,
//           builder: (BuildContext context, ScrollController scrollController) {
//             return Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Center(
//                     child: Container(
//                       width: 40,
//                       height: 5,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[300],
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   Text(
//                     'Read By',
//                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const Divider(height: 24),
//                   Expanded(
//                     child: FutureBuilder<List<UserProfile>>(
//                       future: _chatService.getUsersByIdsOnce(readByUserIds),
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState ==
//                             ConnectionState.waiting) {
//                           return const Center(
//                             child: CircularProgressIndicator(),
//                           );
//                         }
//                         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                           return const Center(
//                             child: Text("No one has read this message yet."),
//                           );
//                         }

//                         final users = snapshot.data!;

//                         return ListView.builder(
//                           controller: scrollController,
//                           itemCount: users.length,
//                           itemBuilder: (context, index) {
//                             final user = users[index];
//                             final readAt = message.readBy[user.uid];
//                             final formattedTime = readAt != null
//                                 ? DateFormat(
//                                     'MMM d, hh:mm a',
//                                   ).format(readAt.toDate())
//                                 : '...';

//                             return ListTile(
//                               leading: CircleAvatar(
//                                 backgroundImage: user.photoURL != null
//                                     ? CachedNetworkImageProvider(user.photoURL!)
//                                     : null,
//                                 child: user.photoURL == null
//                                     ? Text(user.email[0].toUpperCase())
//                                     : null,
//                               ),
//                               title: Text(user.email.split('@')[0]),
//                               subtitle: Text("Read at: $formattedTime"),
//                             );
//                           },
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _showReactionsDialog(Message message, String messageId) {
//     final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
//     final isCurrentUser =
//         message.senderId == _authService.getCurrentUser()!.uid;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Wrap(
//               alignment: WrapAlignment.center,
//               spacing: 12,
//               runSpacing: 12,
//               children: reactions
//                   .map(
//                     (emoji) => GestureDetector(
//                       onTap: () {
//                         final chatRoomId = widget.isGroupChat
//                             ? widget.group!.groupId
//                             : _chatEntityId;
//                         _chatService.toggleMessageReaction(
//                           chatRoomId,
//                           messageId,
//                           emoji,
//                         );
//                         Navigator.of(context).pop();
//                       },
//                       child: Text(emoji, style: const TextStyle(fontSize: 28)),
//                     ),
//                   )
//                   .toList(),
//             ),

//             if (isCurrentUser) const Divider(height: 24),
//             if (isCurrentUser)
//               ListTile(
//                 leading: const Icon(Icons.remove_red_eye),
//                 title: const Text("Seen By"),
//                 onTap: () {
//                   Navigator.of(context).pop();
//                   _showSeenByDialog(context, message);
//                 },
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FA),
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(80),
//         child: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Theme.of(context).primaryColor,
//                 Theme.of(context).primaryColor.withOpacity(0.8),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.1),
//                 blurRadius: 10,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             leading: Container(
//               margin: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: IconButton(
//                 icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ),
//             title: GestureDetector(
//               onTap: () {
//                 if (widget.isGroupChat) {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) =>
//                           GroupInfoScreen(group: widget.group!),
//                     ),
//                   );
//                 }
//               },
//               child: Row(
//                 children: [
//                   if (!widget.isGroupChat)
//                     Hero(
//                       tag: 'avatar_${widget.receiver!.uid}',
//                       child: CircleAvatar(
//                         radius: 22,
//                         backgroundImage: widget.receiver!.photoURL != null
//                             ? CachedNetworkImageProvider(
//                                 widget.receiver!.photoURL!,
//                               )
//                             : null,
//                         backgroundColor: Colors.white.withOpacity(0.3),
//                         child: widget.receiver!.photoURL == null
//                             ? Text(
//                                 widget.receiver!.email[0].toUpperCase(),
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 18,
//                                 ),
//                               )
//                             : null,
//                       ),
//                     )
//                   else
//                     CircleAvatar(
//                       radius: 22,
//                       backgroundColor: Colors.white.withOpacity(0.3),
//                       child: Text(
//                         widget.group!.groupName[0].toUpperCase(),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 18,
//                         ),
//                       ),
//                     ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       widget.isGroupChat
//                           ? widget.group!.groupName
//                           : widget.receiver!.email.split('@')[0],
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               Container(
//                 margin: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: IconButton(
//                   icon: const Icon(Icons.more_vert, color: Colors.white),
//                   onPressed: () {},
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//           Expanded(child: _buildMessageList()),
//           if (!widget.isGroupChat) _buildTypingIndicator(),
//           _buildMessageInput(context),
//         ],
//       ),
//     );
//   }

//   Widget _buildTypingIndicator() {
//     return StreamBuilder<DocumentSnapshot>(
//       stream: _chatService.getChatRoomStream(_chatEntityId),
//       builder: (context, snapshot) {
//         bool isReceiverTyping = false;
//         if (snapshot.hasData && snapshot.data!.data() != null) {
//           final data = snapshot.data!.data() as Map<String, dynamic>;
//           if (data.containsKey('typingStatus') &&
//               data['typingStatus'].containsKey(widget.receiver!.uid)) {
//             isReceiverTyping =
//                 data['typingStatus'][widget.receiver!.uid] ?? false;
//           }
//         }
//         return AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           height: isReceiverTyping ? 50 : 0,
//           child: isReceiverTyping
//               ? Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20.0,
//                     vertical: 8.0,
//                   ),
//                   child: Row(
//                     children: [
//                       const Text(
//                         "typing...",
//                         style: TextStyle(
//                           color: Colors.grey,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                       const SizedBox(width: 6),
//                       const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ),
//                     ],
//                   ),
//                 )
//               : null,
//         );
//       },
//     );
//   }

//   Widget _buildMessageList() {
//     String senderId = _authService.getCurrentUser()!.uid;
//     return StreamBuilder<QuerySnapshot>(
//       stream: widget.isGroupChat
//           ? _chatService.getGroupMessagesStream(_chatEntityId)
//           : _chatService.getMessages(widget.receiver!.uid, senderId),
//       builder: (context, snapshot) {
//         if (snapshot.hasError)
//           return const Center(child: Text("Something went wrong"));
//         if (snapshot.connectionState == ConnectionState.waiting)
//           return const Center(child: CircularProgressIndicator(strokeWidth: 3));

//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           _markVisibleMessagesAsRead(snapshot.data!.docs);
//         });

//         return ListView.builder(
//           controller: _scrollController,
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           itemCount: snapshot.data!.docs.length,
//           itemBuilder: (context, index) {
//             final doc = snapshot.data!.docs[index];
//             return _buildMessageItem(doc);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildMessageItem(DocumentSnapshot doc) {
//     final messageId = doc.id;
//     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//     final message = Message.fromMap(data);
//     final currentUserId = _authService.getCurrentUser()!.uid;
//     bool isCurrentUser = message.senderId == currentUserId;
//     var alignment = isCurrentUser
//         ? Alignment.centerRight
//         : Alignment.centerLeft;
//     final formattedTime = DateFormat(
//       'hh:mm a',
//     ).format(message.timestamp.toDate());

//     return Container(
//       alignment: alignment,
//       margin: const EdgeInsets.symmetric(vertical: 4),
//       child: Column(
//         crossAxisAlignment: isCurrentUser
//             ? CrossAxisAlignment.end
//             : CrossAxisAlignment.start,
//         children: [
//           ChatBubble(
//             message: message.message,
//             isCurrentUser: isCurrentUser,
//             imageUrl: message.imageUrl,
//             type: message.type,
//             reactions: message.reactions,
//             currentUserId: currentUserId,
//             onLongPress: () => _showReactionsDialog(message, messageId),
//             isReply: message.isReply,
//             replyingToMessage: message.replyingToMessage,
//             replyingToSender: message.replyingToSender,
//             onReply: () => setState(() => _replyingToMessage = message),
//             isGroupChat: widget.isGroupChat,
//             senderName: message.senderName,
//             senderPhotoURL: message.senderPhotoURL,
//           ),
//           Padding(
//             padding: const EdgeInsets.only(top: 4.0, right: 8.0, left: 8.0),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   formattedTime,
//                   style: TextStyle(fontSize: 11, color: Colors.grey[500]),
//                 ),
//                 if (isCurrentUser) const SizedBox(width: 4),
//                 if (isCurrentUser) _buildReadReceipt(message),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildReadReceipt(Message message) {
//     if (message.senderId != _authService.getCurrentUser()!.uid)
//       return const SizedBox.shrink();

//     final totalMembers = widget.isGroupChat
//         ? widget.group?.members.length ?? 0
//         : 2;
//     final bool allRead =
//         totalMembers > 1 && message.readBy.length >= totalMembers;
//     final icon = allRead ? Icons.done_all : Icons.done;
//     final color = allRead ? Colors.blueAccent : Colors.grey;

//     return GestureDetector(
//       onTap: () {
//         _showSeenByDialog(context, message);
//       },
//       child: Icon(icon, size: 18, color: color),
//     );
//   }

//   Widget _buildMessageInput(BuildContext context) {
//     final bool showSendButton = _messageController.text.isNotEmpty;
//     return Column(
//       children: [
//         if (_replyingToMessage != null)
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: Theme.of(context).primaryColor.withOpacity(0.1),
//               border: Border(top: BorderSide(color: Colors.grey[300]!)),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.reply,
//                   size: 20,
//                   color: Theme.of(context).primaryColor,
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Replying to ${_replyingToMessage!.senderEmail.split('@')[0]}",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Theme.of(context).primaryColor,
//                           fontSize: 13,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         _replyingToMessage!.type == 'image'
//                             ? 'An image'
//                             : _replyingToMessage!.message,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(color: Colors.grey[700], fontSize: 13),
//                       ),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.close, size: 20),
//                   onPressed: () => setState(() => _replyingToMessage = null),
//                 ),
//               ],
//             ),
//           ),
//         Container(
//           padding: const EdgeInsets.all(16.0),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 10,
//                 offset: const Offset(0, -2),
//               ),
//             ],
//           ),
//           child: SafeArea(
//             child: Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.add_photo_alternate_rounded),
//                   onPressed: _sendImage,
//                   color: Theme.of(context).primaryColor,
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.grey[100],
//                       borderRadius: BorderRadius.circular(25),
//                       border: Border.all(color: Colors.grey[300]!),
//                     ),
//                     child: TextField(
//                       controller: _messageController,
//                       decoration: InputDecoration(
//                         hintText: 'Type a message...',
//                         hintStyle: TextStyle(color: Colors.grey[500]),
//                         border: InputBorder.none,
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 12,
//                         ),
//                       ),
//                       onSubmitted: (_) => _sendMessage(),
//                       maxLines: 3,
//                       minLines: 1,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 200),
//                   transitionBuilder: (child, animation) =>
//                       ScaleTransition(scale: animation, child: child),
//                   child: showSendButton
//                       ? IconButton(
//                           key: const ValueKey('send_button'),
//                           icon: const Icon(Icons.send_rounded),
//                           onPressed: _sendMessage,
//                           color: Theme.of(context).primaryColor,
//                         )
//                       : IconButton(
//                           key: const ValueKey('mic_button'),
//                           icon: const Icon(Icons.mic_rounded),
//                           onPressed: () {},
//                           color: Theme.of(context).primaryColor,
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
// import 'dart:async';
// import 'package:dynamichatapp/models/group_profile.dart';
// import 'package:dynamichatapp/models/message.dart';
// import 'package:dynamichatapp/screens/group_info_screen.dart';
// import 'package:dynamichatapp/services/storage_service.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import '../services/auth_service.dart';
// import '../services/chat_service.dart';
// import '../models/user_profile.dart';
// import '../widgets/chat_bubble.dart';

// class ChatScreen extends StatefulWidget {
//   final UserProfile? receiver;
//   final GroupProfile? group;
//   final bool isGroupChat;

//   const ChatScreen({
//     super.key,
//     this.receiver,
//     this.group,
//     this.isGroupChat = false,
//   });

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
//   final TextEditingController _messageController = TextEditingController();
//   final ChatService _chatService = ChatService();
//   final AuthService _authService = AuthService();
//   final StorageService _storageService = StorageService();
//   final ImagePicker _picker = ImagePicker();
//   final ScrollController _scrollController = ScrollController();

//   Timer? _typingTimer;
//   late String _chatEntityId;
//   Message? _replyingToMessage;

//   @override
//   void initState() {
//     super.initState();

//     if (widget.isGroupChat) {
//       _chatEntityId = widget.group!.groupId;
//     } else {
//       List<String> ids = [
//         _authService.getCurrentUser()!.uid,
//         widget.receiver!.uid,
//       ];
//       ids.sort();
//       _chatEntityId = ids.join('_');
//     }

//     _messageController.addListener(_onTyping);
//   }

//   @override
//   void dispose() {
//     _messageController.removeListener(_onTyping);
//     _scrollController.dispose();
//     _typingTimer?.cancel();
//     if (!widget.isGroupChat) {
//       _chatService.updateTypingStatus(
//         _chatEntityId,
//         _authService.getCurrentUser()!.uid,
//         false,
//       );
//     }
//     super.dispose();
//   }

//   void _onTyping() {
//     setState(() {});
//     if (widget.isGroupChat) return;
//     final currentUser = _authService.getCurrentUser()!;
//     _typingTimer?.cancel();
//     if (_messageController.text.isNotEmpty) {
//       _chatService.updateTypingStatus(_chatEntityId, currentUser.uid, true);
//     }
//     _typingTimer = Timer(const Duration(seconds: 2), () {
//       _chatService.updateTypingStatus(_chatEntityId, currentUser.uid, false);
//     });
//   }

//   void _markVisibleMessagesAsRead(List<QueryDocumentSnapshot> messages) {
//     for (var doc in messages) {
//       final message = Message.fromMap(doc.data() as Map<String, dynamic>);
//       final isReadByCurrentUser = message.readBy.containsKey(
//         _authService.getCurrentUser()!.uid,
//       );

//       if (message.senderId != _authService.getCurrentUser()!.uid &&
//           !isReadByCurrentUser) {
//         _chatService.markMessageAsRead(
//           _chatEntityId,
//           doc.id,
//           widget.isGroupChat,
//         );
//       }
//     }
//   }

//   void _sendMessage() async {
//     if (_messageController.text.isNotEmpty) {
//       final receiverId = widget.isGroupChat
//           ? widget.group!.groupId
//           : widget.receiver!.uid;
//       await _chatService.sendMessage(
//         receiverId,
//         isGroup: widget.isGroupChat,
//         text: _messageController.text,
//         repliedToMessage: _replyingToMessage,
//       );
//       _messageController.clear();
//       setState(() {
//         _replyingToMessage = null;
//       });
//     }
//   }

//   void _sendImage() async {
//     final XFile? image = await _picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 70,
//     );
//     if (image != null) {
//       final imageUrl = await _storageService.uploadChatImage(
//         image,
//         _chatEntityId,
//       );
//       if (imageUrl != null) {
//         final receiverId = widget.isGroupChat
//             ? widget.group!.groupId
//             : widget.receiver!.uid;
//         await _chatService.sendMessage(
//           receiverId,
//           isGroup: widget.isGroupChat,
//           imageUrl: imageUrl,
//           repliedToMessage: _replyingToMessage,
//         );
//         setState(() {
//           _replyingToMessage = null;
//         });
//       }
//     }
//   }

//   // void _showSeenByDialog(BuildContext context, Message message) {
//   //   final readByUserIds = message.readBy.keys.toList();

//   //   showModalBottomSheet(
//   //     context: context,
//   //     isScrollControlled: true,
//   //     shape: const RoundedRectangleBorder(
//   //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//   //     ),
//   //     builder: (context) {
//   //       return DraggableScrollableSheet(
//   //         expand: false,
//   //         initialChildSize: 0.5,
//   //         minChildSize: 0.3,
//   //         maxChildSize: 0.8,
//   //         builder: (BuildContext context, ScrollController scrollController) {
//   //           return Container(
//   //             padding: const EdgeInsets.all(16),
//   //             child: Column(
//   //               crossAxisAlignment: CrossAxisAlignment.start,
//   //               children: [
//   //                 Center(
//   //                   child: Container(
//   //                     width: 40,
//   //                     height: 5,
//   //                     decoration: BoxDecoration(
//   //                       color: Colors.grey[300],
//   //                       borderRadius: BorderRadius.circular(12),
//   //                     ),
//   //                   ),
//   //                 ),
//   //                 const SizedBox(height: 20),
//   //                 Text(
//   //                   'Read By',
//   //                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//   //                     fontWeight: FontWeight.bold,
//   //                   ),
//   //                 ),
//   //                 const Divider(height: 24),
//   //                 Expanded(
//   //                   child: FutureBuilder<List<UserProfile>>(
//   //                     future: _chatService.getUsersByIdsOnce(readByUserIds),
//   //                     builder: (context, snapshot) {
//   //                       if (snapshot.connectionState ==
//   //                           ConnectionState.waiting) {
//   //                         return const Center(
//   //                           child: CircularProgressIndicator(),
//   //                         );
//   //                       }
//   //                       if (!snapshot.hasData || snapshot.data!.isEmpty) {
//   //                         return const Center(
//   //                           child: Text("No one has read this message yet."),
//   //                         );
//   //                       }

//   //                       final users = snapshot.data!;

//   //                       return ListView.builder(
//   //                         controller: scrollController,
//   //                         itemCount: users.length,
//   //                         itemBuilder: (context, index) {
//   //                           final user = users[index];
//   //                           final readAt = message.readBy[user.uid];
//   //                           final formattedTime = readAt != null
//   //                               ? DateFormat(
//   //                                   'MMM d, hh:mm a',
//   //                                 ).format(readAt.toDate())
//   //                               : '...';

//   //                           return ListTile(
//   //                             leading: CircleAvatar(
//   //                               backgroundImage: user.photoURL != null
//   //                                   ? CachedNetworkImageProvider(user.photoURL!)
//   //                                   : null,
//   //                               child: user.photoURL == null
//   //                                   ? Text(user.email[0].toUpperCase())
//   //                                   : null,
//   //                             ),
//   //                             title: Text(user.email.split('@')[0]),
//   //                             subtitle: Text("Read at: $formattedTime"),
//   //                           );
//   //                         },
//   //                       );
//   //                     },
//   //                   ),
//   //                 ),
//   //               ],
//   //             ),
//   //           );
//   //         },
//   //       );
//   //     },
//   //   );
//   // }

//   void _showSeenByDialog(BuildContext context, Message message) {
//     final readByUserIds = message.readBy.keys.toList();

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return DraggableScrollableSheet(
//           expand: false,
//           initialChildSize: 0.5,
//           minChildSize: 0.3,
//           maxChildSize: 0.8,
//           builder: (BuildContext context, ScrollController scrollController) {
//             return Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Center(
//                     child: Container(
//                       width: 40,
//                       height: 5,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[300],
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   Text(
//                     'Read By',
//                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const Divider(height: 24),
//                   Expanded(
//                     child: FutureBuilder<List<UserProfile>>(
//                       future: _chatService.getUsersByIdsOnce(readByUserIds),
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState ==
//                             ConnectionState.waiting) {
//                           return const Center(
//                             child: CircularProgressIndicator(),
//                           );
//                         }
//                         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                           return const Center(
//                             child: Text("No one has read this message yet."),
//                           );
//                         }

//                         final users = snapshot.data!;

//                         return ListView.builder(
//                           controller: scrollController,
//                           itemCount: users.length,
//                           itemBuilder: (context, index) {
//                             final user = users[index];
//                             final readAt = message.readBy[user.uid];
//                             final formattedTime = readAt != null
//                                 ? DateFormat(
//                                     'MMM d, hh:mm a',
//                                   ).format(readAt.toDate())
//                                 : '...';

//                             return ListTile(
//                               leading: CircleAvatar(
//                                 backgroundImage: user.photoURL != null
//                                     ? CachedNetworkImageProvider(user.photoURL!)
//                                     : null,
//                                 child: user.photoURL == null
//                                     ? Text(user.email[0].toUpperCase())
//                                     : null,
//                               ),
//                               title: Text(user.email.split('@')[0]),
//                               subtitle: Text("Read at: $formattedTime"),
//                             );
//                           },
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   // void _showReactionsDialog(Message message, String messageId) {
//   //   final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
//   //   final isCurrentUser =
//   //       message.senderId == _authService.getCurrentUser()!.uid;

//   //   showDialog(
//   //     context: context,
//   //     builder: (context) => AlertDialog(
//   //       backgroundColor: Colors.white,
//   //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//   //       content: Column(
//   //         mainAxisSize: MainAxisSize.min,
//   //         children: [
//   //           Wrap(
//   //             alignment: WrapAlignment.center,
//   //             spacing: 12,
//   //             runSpacing: 12,
//   //             children: reactions
//   //                 .map(
//   //                   (emoji) => GestureDetector(
//   //                     onTap: () {
//   //                       _chatService.toggleMessageReaction(
//   //                         _chatEntityId,
//   //                         messageId,
//   //                         emoji,
//   //                         //isGroupChat: widget.isGroupChat
//   //                       );
//   //                       Navigator.of(context).pop();
//   //                     },
//   //                     child: Text(emoji, style: const TextStyle(fontSize: 28)),
//   //                   ),
//   //                 )
//   //                 .toList(),
//   //           ),

//   //           if (isCurrentUser) const Divider(height: 24),
//   //           if (isCurrentUser)
//   //             ListTile(
//   //               leading: const Icon(Icons.remove_red_eye),
//   //               title: const Text("Seen By"),
//   //               onTap: () {
//   //                 Navigator.of(context).pop();
//   //                 _showSeenByDialog(context, message);
//   //               },
//   //             ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }

//   void _showReactionsDialog(Message message, String messageId) {
//     final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
//     final isCurrentUser =
//         message.senderId == _authService.getCurrentUser()!.uid;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Wrap(
//               alignment: WrapAlignment.center,
//               spacing: 12,
//               runSpacing: 12,
//               children: reactions
//                   .map(
//                     (emoji) => GestureDetector(
//                       onTap: () {
//                         _chatService.toggleMessageReaction(
//                           _chatEntityId,
//                           messageId,
//                           emoji,
//                         );
//                         Navigator.of(context).pop();
//                       },
//                       child: Text(emoji, style: const TextStyle(fontSize: 28)),
//                     ),
//                   )
//                   .toList(),
//             ),

//             if (isCurrentUser) const Divider(height: 24),
//             if (isCurrentUser)
//               ListTile(
//                 leading: const Icon(Icons.remove_red_eye),
//                 title: const Text("Seen By"),
//                 onTap: () {
//                   Navigator.of(context).pop();
//                   _showSeenByDialog(context, message);
//                 },
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FA),
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(80),
//         child: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Theme.of(context).primaryColor,
//                 Theme.of(context).primaryColor.withOpacity(0.8),
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.1),
//                 blurRadius: 10,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             leading: Container(
//               margin: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: IconButton(
//                 icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ),
//             title: GestureDetector(
//               onTap: () {
//                 if (widget.isGroupChat) {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) =>
//                           GroupInfoScreen(group: widget.group!),
//                     ),
//                   );
//                 }
//               },
//               child: Row(
//                 children: [
//                   if (!widget.isGroupChat)
//                     Hero(
//                       tag: 'avatar_${widget.receiver!.uid}',
//                       child: CircleAvatar(
//                         radius: 22,
//                         backgroundImage: widget.receiver!.photoURL != null
//                             ? CachedNetworkImageProvider(
//                                 widget.receiver!.photoURL!,
//                               )
//                             : null,
//                         backgroundColor: Colors.white.withOpacity(0.3),
//                         child: widget.receiver!.photoURL == null
//                             ? Text(
//                                 widget.receiver!.email[0].toUpperCase(),
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 18,
//                                 ),
//                               )
//                             : null,
//                       ),
//                     )
//                   else
//                     CircleAvatar(
//                       radius: 22,
//                       backgroundColor: Colors.white.withOpacity(0.3),
//                       child: Text(
//                         widget.group!.groupName[0].toUpperCase(),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 18,
//                         ),
//                       ),
//                     ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       widget.isGroupChat
//                           ? widget.group!.groupName
//                           : widget.receiver!.email.split('@')[0],
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               Container(
//                 margin: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: IconButton(
//                   icon: const Icon(Icons.more_vert, color: Colors.white),
//                   onPressed: () {},
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//           Expanded(child: _buildMessageList()),
//           if (!widget.isGroupChat) _buildTypingIndicator(),
//           _buildMessageInput(context),
//         ],
//       ),
//     );
//   }

//   // Widget _buildMessageList() {
//   //   String senderId = _authService.getCurrentUser()!.uid;
//   //   return StreamBuilder<QuerySnapshot>(
//   //     stream: widget.isGroupChat
//   //         ? _chatService.getGroupMessagesStream(_chatEntityId)
//   //         : _chatService.getMessages(widget.receiver!.uid, senderId),
//   //     builder: (context, snapshot) {
//   //       if (snapshot.hasError) {
//   //         return const Center(child: Text("Something went wrong"));
//   //       }
//   //       if (snapshot.connectionState == ConnectionState.waiting) {
//   //         return const Center(child: CircularProgressIndicator(strokeWidth: 3));
//   //       }

//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         _markVisibleMessagesAsRead(snapshot.data!.docs);
//   //       });

//   //       return ListView.builder(
//   //         controller: _scrollController,
//   //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//   //         itemCount: snapshot.data!.docs.length,
//   //         itemBuilder: (context, index) {
//   //           final doc = snapshot.data!.docs[index];
//   //           return _buildMessageItem(doc);
//   //         },
//   //       );
//   //     },
//   //   );
//   // }

//   Widget _buildMessageList() {
//     String senderId = _authService.getCurrentUser()!.uid;
//     return StreamBuilder<QuerySnapshot>(
//       stream: widget.isGroupChat
//           ? _chatService.getGroupMessagesStream(_chatEntityId)
//           : _chatService.getMessages(widget.receiver!.uid, senderId),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return const Center(child: Text("Something went wrong"));
//         }
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator(strokeWidth: 3));
//         }

//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           _markVisibleMessagesAsRead(snapshot.data!.docs);
//         });

//         return ListView.builder(
//           controller: _scrollController,
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           itemCount: snapshot.data!.docs.length,
//           itemBuilder: (context, index) {
//             final doc = snapshot.data!.docs[index];
//             return _buildMessageItem(doc);
//           },
//         );
//       },
//     );
//   }

//   // Widget _buildMessageItem(DocumentSnapshot doc) {
//   //   final messageId = doc.id;
//   //   Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//   //   final message = Message.fromMap(data);
//   //   final currentUserId = _authService.getCurrentUser()!.uid;
//   //   bool isCurrentUser = message.senderId == currentUserId;
//   //   var alignment = isCurrentUser
//   //       ? Alignment.centerRight
//   //       : Alignment.centerLeft;
//   //   final formattedTime = DateFormat(
//   //     'hh:mm a',
//   //   ).format(message.timestamp.toDate());

//   //   return Container(
//   //     alignment: alignment,
//   //     margin: const EdgeInsets.symmetric(vertical: 4),
//   //     child: Column(
//   //       crossAxisAlignment: isCurrentUser
//   //           ? CrossAxisAlignment.end
//   //           : CrossAxisAlignment.start,
//   //       children: [
//   //         ChatBubble(
//   //           message: message.message,
//   //           isCurrentUser: isCurrentUser,
//   //           imageUrl: message.imageUrl,
//   //           type: message.type,
//   //           reactions: message.reactions,
//   //           currentUserId: currentUserId,
//   //           onLongPress: () => _showReactionsDialog(message, messageId),
//   //           isReply: message.isReply,
//   //           replyingToMessage: message.replyingToMessage,
//   //           replyingToSender: message.replyingToSender,
//   //           onReply: () => setState(() => _replyingToMessage = message),
//   //           isGroupChat: widget.isGroupChat,
//   //           senderName: message.senderName,
//   //           senderPhotoURL: message.senderPhotoURL,
//   //         ),
//   //         Padding(
//   //           padding: const EdgeInsets.only(top: 4.0, right: 8.0, left: 8.0),
//   //           child: Row(
//   //             mainAxisSize: MainAxisSize.min,
//   //             children: [
//   //               Text(
//   //                 formattedTime,
//   //                 style: TextStyle(fontSize: 11, color: Colors.grey[500]),
//   //               ),
//   //               if (isCurrentUser) const SizedBox(width: 4),
//   //               if (isCurrentUser) _buildReadReceipt(message),
//   //             ],
//   //           ),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }

//   Widget _buildMessageItem(DocumentSnapshot doc) {
//     final messageId = doc.id;
//     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//     final message = Message.fromMap(data);
//     final currentUserId = _authService.getCurrentUser()!.uid;
//     bool isCurrentUser = message.senderId == currentUserId;
//     var alignment = isCurrentUser
//         ? Alignment.centerRight
//         : Alignment.centerLeft;
//     final formattedTime = DateFormat(
//       'hh:mm a',
//     ).format(message.timestamp.toDate());

//     return Container(
//       alignment: alignment,
//       margin: const EdgeInsets.symmetric(vertical: 4),
//       child: Column(
//         crossAxisAlignment: isCurrentUser
//             ? CrossAxisAlignment.end
//             : CrossAxisAlignment.start,
//         children: [
//           ChatBubble(
//             message: message.message,
//             isCurrentUser: isCurrentUser,
//             imageUrl: message.imageUrl,
//             type: message.type,
//             reactions: message.reactions,
//             currentUserId: currentUserId,
//             onLongPress: () => _showReactionsDialog(message, messageId),
//             isReply: message.isReply,
//             replyingToMessage: message.replyingToMessage,
//             replyingToSender: message.replyingToSender,
//             onReply: () => setState(() => _replyingToMessage = message),
//             isGroupChat: widget.isGroupChat,
//             senderName: message.senderName,
//             senderPhotoURL: message.senderPhotoURL,
//           ),
//           Padding(
//             padding: const EdgeInsets.only(top: 4.0, right: 8.0, left: 8.0),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   formattedTime,
//                   style: TextStyle(fontSize: 11, color: Colors.grey[500]),
//                 ),
//                 if (isCurrentUser) const SizedBox(width: 4),
//                 if (isCurrentUser) _buildReadReceipt(message),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Widget _buildReadReceipt(Message message) {
//   //   if (message.senderId != _authService.getCurrentUser()!.uid)
//   //     return const SizedBox.shrink();

//   //   bool isSeenByReceiver;

//   //   if (widget.isGroupChat) {
//   //     final totalMembers = widget.group?.members.length ?? 0;
//   //     isSeenByReceiver =
//   //         totalMembers > 1 && message.readBy.length >= totalMembers;
//   //   } else {
//   //     isSeenByReceiver = message.readBy.containsKey(widget.receiver!.uid);
//   //   }

//   //   final icon = isSeenByReceiver ? Icons.done_all : Icons.done;
//   //   final color = isSeenByReceiver ? Colors.blueAccent : Colors.grey;

//   //   return GestureDetector(
//   //     onTap: () {
//   //       _showSeenByDialog(context, message);
//   //     },
//   //     child: Icon(icon, size: 18, color: color),
//   //   );
//   // }

//   // Widget _buildReadReceipt(Message message) {
//   //   if (message.senderId != _authService.getCurrentUser()!.uid)
//   //     return const SizedBox.shrink();

//   //   bool isSeenByReceiver;

//   //   if (widget.isGroupChat) {
//   //     final totalMembers = widget.group?.members.length ?? 0;
//   //     isSeenByReceiver =
//   //         totalMembers > 1 && message.readBy.length >= totalMembers;
//   //   } else {
//   //     // For one-on-one chat, just check if the receiver's ID is in the readBy map
//   //     isSeenByReceiver = message.readBy.containsKey(widget.receiver!.uid);
//   //   }

//   //   final icon = isSeenByReceiver ? Icons.done_all : Icons.done;
//   //   final color = isSeenByReceiver ? Colors.blueAccent : Colors.grey;

//   //   return GestureDetector(
//   //     onTap: () {
//   //       if (widget.isGroupChat) {
//   //         _showSeenByDialog(context, message);
//   //       }
//   //     },
//   //     child: Icon(icon, size: 18, color: color),
//   //   );
//   // }

//   Widget _buildReadReceipt(Message message) {
//     if (message.senderId != _authService.getCurrentUser()!.uid)
//       return const SizedBox.shrink();

//     bool isSeenByReceiver;

//     if (widget.isGroupChat) {
//       final totalMembers = widget.group?.members.length ?? 0;
//       isSeenByReceiver =
//           totalMembers > 1 && message.readBy.length >= totalMembers;
//     } else {
//       // For one-on-one chat, just check if the receiver's ID is in the readBy map
//       isSeenByReceiver = message.readBy.containsKey(widget.receiver!.uid);
//     }

//     final icon = isSeenByReceiver ? Icons.done_all : Icons.done;
//     final color = isSeenByReceiver ? Colors.blueAccent : Colors.grey;

//     return GestureDetector(
//       onTap: () {
//         if (widget.isGroupChat) {
//           _showSeenByDialog(context, message);
//         }
//       },
//       child: Icon(icon, size: 18, color: color),
//     );
//   }

//   Widget _buildMessageInput(BuildContext context) {
//     final bool showSendButton = _messageController.text.isNotEmpty;
//     return Column(
//       children: [
//         if (_replyingToMessage != null)
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: Theme.of(context).primaryColor.withOpacity(0.1),
//               border: Border(top: BorderSide(color: Colors.grey[300]!)),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.reply,
//                   size: 20,
//                   color: Theme.of(context).primaryColor,
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Replying to ${_replyingToMessage!.senderEmail.split('@')[0]}",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Theme.of(context).primaryColor,
//                           fontSize: 13,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         _replyingToMessage!.type == 'image'
//                             ? 'An image'
//                             : _replyingToMessage!.message,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(color: Colors.grey[700], fontSize: 13),
//                       ),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.close, size: 20),
//                   onPressed: () => setState(() => _replyingToMessage = null),
//                 ),
//               ],
//             ),
//           ),
//         Container(
//           padding: const EdgeInsets.all(16.0),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 10,
//                 offset: const Offset(0, -2),
//               ),
//             ],
//           ),
//           child: SafeArea(
//             child: Row(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.add_photo_alternate_rounded),
//                   onPressed: _sendImage,
//                   color: Theme.of(context).primaryColor,
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.grey[100],
//                       borderRadius: BorderRadius.circular(25),
//                       border: Border.all(color: Colors.grey[300]!),
//                     ),
//                     child: TextField(
//                       controller: _messageController,
//                       decoration: InputDecoration(
//                         hintText: 'Type a message...',
//                         hintStyle: TextStyle(color: Colors.grey[500]),
//                         border: InputBorder.none,
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 12,
//                         ),
//                       ),
//                       onSubmitted: (_) => _sendMessage(),
//                       maxLines: 3,
//                       minLines: 1,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 200),
//                   transitionBuilder: (child, animation) =>
//                       ScaleTransition(scale: animation, child: child),
//                   child: showSendButton
//                       ? IconButton(
//                           key: const ValueKey('send_button'),
//                           icon: const Icon(Icons.send_rounded),
//                           onPressed: _sendMessage,
//                           color: Theme.of(context).primaryColor,
//                         )
//                       : IconButton(
//                           key: const ValueKey('mic_button'),
//                           icon: const Icon(Icons.mic_rounded),
//                           onPressed: () {},
//                           color: Theme.of(context).primaryColor,
//                         ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTypingIndicator() {
//     return StreamBuilder<DocumentSnapshot>(
//       stream: _chatService.getChatRoomStream(_chatEntityId),
//       builder: (context, snapshot) {
//         bool isReceiverTyping = false;
//         if (snapshot.hasData && snapshot.data!.data() != null) {
//           final data = snapshot.data!.data() as Map<String, dynamic>;
//           if (data.containsKey('typingStatus') &&
//               data['typingStatus'].containsKey(widget.receiver!.uid)) {
//             isReceiverTyping =
//                 data['typingStatus'][widget.receiver!.uid] ?? false;
//           }
//         }
//         return AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           height: isReceiverTyping ? 50 : 0,
//           child: isReceiverTyping
//               ? Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20.0,
//                     vertical: 8.0,
//                   ),
//                   child: Row(
//                     children: [
//                       const Text(
//                         "typing...",
//                         style: TextStyle(
//                           color: Colors.grey,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                       const SizedBox(width: 6),
//                       const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ),
//                     ],
//                   ),
//                 )
//               : null,
//         );
//       },
//     );
//   }
// }

import 'dart:async';
import 'package:dynamichatapp/models/group_profile.dart';
import 'package:dynamichatapp/models/message.dart';
import 'package:dynamichatapp/screens/group_info_screen.dart';
import 'package:dynamichatapp/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_profile.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final UserProfile? receiver;
  final GroupProfile? group;
  final bool isGroupChat;

  const ChatScreen({
    super.key,
    this.receiver,
    this.group,
    this.isGroupChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  Timer? _typingTimer;
  late String _chatEntityId;
  Message? _replyingToMessage;

  @override
  void initState() {
    super.initState();

    if (widget.isGroupChat) {
      _chatEntityId = widget.group!.groupId;
    } else {
      List<String> ids = [
        _authService.getCurrentUser()!.uid,
        widget.receiver!.uid,
      ];
      ids.sort();
      _chatEntityId = ids.join('_');
    }

    _messageController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping);
    _scrollController.dispose();
    _typingTimer?.cancel();
    if (!widget.isGroupChat) {
      _chatService.updateTypingStatus(
        _chatEntityId,
        _authService.getCurrentUser()!.uid,
        false,
      );
    }
    super.dispose();
  }

  void _onTyping() {
    setState(() {});
    if (widget.isGroupChat) return;
    final currentUser = _authService.getCurrentUser()!;
    _typingTimer?.cancel();
    if (_messageController.text.isNotEmpty) {
      _chatService.updateTypingStatus(_chatEntityId, currentUser.uid, true);
    }
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTypingStatus(_chatEntityId, currentUser.uid, false);
    });
  }

  // void _markVisibleMessagesAsRead(List<QueryDocumentSnapshot> messages) {
  //   for (var doc in messages) {
  //     final message = Message.fromMap(doc.data() as Map<String, dynamic>);
  //     final isReadByCurrentUser = message.readBy.containsKey(
  //       _authService.getCurrentUser()!.uid,
  //     );

  //     if (message.senderId != _authService.getCurrentUser()!.uid &&
  //         !isReadByCurrentUser) {
  //       _chatService.markMessageAsRead(
  //         _chatEntityId,
  //         doc.id,
  //         widget.isGroupChat,
  //       );
  //     }
  //   }
  // }

  // ... inside the _ChatScreenState class

  void _markVisibleMessagesAsRead(List<QueryDocumentSnapshot> messages) {
    for (var doc in messages) {
      final message = Message.fromMap(doc.data() as Map<String, dynamic>);
      final isReadByCurrentUser = message.readBy.containsKey(
        _authService.getCurrentUser()!.uid,
      );

      if (message.senderId != _authService.getCurrentUser()!.uid &&
          !isReadByCurrentUser) {
        // --- THIS IS THE FIX ---
        // Use an if/else block to call the correct, dedicated function
        if (widget.isGroupChat) {
          _chatService.markGroupMessageAsRead(_chatEntityId, doc.id);
        } else {
          _chatService.markPersonalMessageAsRead(_chatEntityId, doc.id);
        }
        // -----------------------
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final receiverId = widget.isGroupChat
          ? widget.group!.groupId
          : widget.receiver!.uid;
      await _chatService.sendMessage(
        receiverId,
        isGroup: widget.isGroupChat,
        text: _messageController.text,
        repliedToMessage: _replyingToMessage,
      );
      _messageController.clear();
      setState(() {
        _replyingToMessage = null;
      });
    }
  }

  void _sendImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      final imageUrl = await _storageService.uploadChatImage(
        image,
        _chatEntityId,
      );
      if (imageUrl != null) {
        final receiverId = widget.isGroupChat
            ? widget.group!.groupId
            : widget.receiver!.uid;
        await _chatService.sendMessage(
          receiverId,
          isGroup: widget.isGroupChat,
          imageUrl: imageUrl,
          repliedToMessage: _replyingToMessage,
        );
        setState(() {
          _replyingToMessage = null;
        });
      }
    }
  }

  void _showSeenByDialog(BuildContext context, Message message) {
    final readByUserIds = message.readBy.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Read By',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: FutureBuilder<List<UserProfile>>(
                      future: _chatService.getUsersByIdsOnce(readByUserIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text("No one has read this message yet."),
                          );
                        }

                        final users = snapshot.data!;

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final readAt = message.readBy[user.uid];
                            final formattedTime = readAt != null
                                ? DateFormat(
                                    'MMM d, hh:mm a',
                                  ).format(readAt.toDate())
                                : '...';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user.photoURL != null
                                    ? CachedNetworkImageProvider(user.photoURL!)
                                    : null,
                                child: user.photoURL == null
                                    ? Text(user.email[0].toUpperCase())
                                    : null,
                              ),
                              title: Text(user.email.split('@')[0]),
                              subtitle: Text("Read at: $formattedTime"),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReactionsDialog(Message message, String messageId) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    final isCurrentUser =
        message.senderId == _authService.getCurrentUser()!.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: reactions
                  .map(
                    (emoji) => GestureDetector(
                      onTap: () {
                        _chatService.toggleMessageReaction(
                          _chatEntityId,
                          messageId,
                          emoji,
                        );
                        Navigator.of(context).pop();
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList(),
            ),

            if (isCurrentUser) const Divider(height: 24),
            if (isCurrentUser)
              ListTile(
                leading: const Icon(Icons.remove_red_eye),
                title: const Text("Seen By"),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSeenByDialog(context, message);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                if (widget.isGroupChat) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GroupInfoScreen(group: widget.group!),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  if (!widget.isGroupChat)
                    Hero(
                      tag: 'avatar_${widget.receiver!.uid}',
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: widget.receiver!.photoURL != null
                            ? CachedNetworkImageProvider(
                                widget.receiver!.photoURL!,
                              )
                            : null,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: widget.receiver!.photoURL == null
                            ? Text(
                                widget.receiver!.email[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        widget.group!.groupName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isGroupChat
                          ? widget.group!.groupName
                          : widget.receiver!.email.split('@')[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (!widget.isGroupChat) _buildTypingIndicator(),
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    String senderId = _authService.getCurrentUser()!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: widget.isGroupChat
          ? _chatService.getGroupMessagesStream(_chatEntityId)
          : _chatService.getMessages(widget.receiver!.uid, senderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Something went wrong"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markVisibleMessagesAsRead(snapshot.data!.docs);
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            return _buildMessageItem(doc);
          },
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    final messageId = doc.id;
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final message = Message.fromMap(data);
    final currentUserId = _authService.getCurrentUser()!.uid;
    bool isCurrentUser = message.senderId == currentUserId;
    var alignment = isCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final formattedTime = DateFormat(
      'hh:mm a',
    ).format(message.timestamp.toDate());

    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: message.message,
            isCurrentUser: isCurrentUser,
            imageUrl: message.imageUrl,
            type: message.type,
            reactions: message.reactions,
            currentUserId: currentUserId,
            onLongPress: () => _showReactionsDialog(message, messageId),
            isReply: message.isReply,
            replyingToMessage: message.replyingToMessage,
            replyingToSender: message.replyingToSender,
            onReply: () => setState(() => _replyingToMessage = message),
            isGroupChat: widget.isGroupChat,
            senderName: message.senderName,
            senderPhotoURL: message.senderPhotoURL,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, right: 8.0, left: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (isCurrentUser) const SizedBox(width: 4),
                if (isCurrentUser) _buildReadReceipt(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- THIS IS THE FINAL FIX FOR THE BLUE TICKS ---
  // Widget _buildReadReceipt(Message message) {
  //   if (message.senderId != _authService.getCurrentUser()!.uid)
  //     return const SizedBox.shrink();

  //   bool isSeenByReceiver;

  //   if (widget.isGroupChat) {
  //     final totalMembers = widget.group?.members.length ?? 0;
  //     isSeenByReceiver =
  //         totalMembers > 1 && message.readBy.length >= totalMembers;
  //   } else {
  //     // For one-on-one chat, just check if the receiver's ID is in the readBy map
  //     isSeenByReceiver = message.readBy.containsKey(widget.receiver!.uid);
  //   }

  //   final icon = isSeenByReceiver ? Icons.done_all : Icons.done;
  //   final color = isSeenByReceiver ? Colors.blueAccent : Colors.grey;

  //   return GestureDetector(
  //     onTap: () {
  //       if (widget.isGroupChat) {
  //         _showSeenByDialog(context, message);
  //       }
  //     },
  //     child: Icon(icon, size: 18, color: color),
  //   );
  // }

  // --- THIS IS THE FINAL AND CORRECT WIDGET ---
  Widget _buildReadReceipt(Message message) {
    // It should not show a receipt for messages you've received.
    if (message.senderId != _authService.getCurrentUser()!.uid)
      return const SizedBox.shrink();

    bool isSeenByReceiver;

    if (widget.isGroupChat) {
      // For groups, check if the number of reads is equal to or greater than the number of members.
      final totalMembers = widget.group?.members.length ?? 0;
      isSeenByReceiver =
          totalMembers > 1 && message.readBy.length >= totalMembers;
    } else {
      // For one-on-one chats, simply check if the receiver's ID is in the `readBy` map.
      isSeenByReceiver = message.readBy.containsKey(widget.receiver!.uid);
    }

    // Determine the icon and color based on the seen status.
    final icon = isSeenByReceiver ? Icons.done_all : Icons.done;
    final color = isSeenByReceiver ? Colors.blueAccent : Colors.grey;

    return GestureDetector(
      onTap: () {
        // The "Seen By" details dialog is only for group chats.
        if (widget.isGroupChat) {
          _showSeenByDialog(context, message);
        }
      },
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    final bool showSendButton = _messageController.text.isNotEmpty;
    return Column(
      children: [
        if (_replyingToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Replying to ${_replyingToMessage!.senderEmail.split('@')[0]}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyingToMessage!.type == 'image'
                            ? 'An image'
                            : _replyingToMessage!.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _replyingToMessage = null),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  onPressed: _sendImage,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: showSendButton
                      ? IconButton(
                          key: const ValueKey('send_button'),
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _sendMessage,
                          color: Theme.of(context).primaryColor,
                        )
                      : IconButton(
                          key: const ValueKey('mic_button'),
                          icon: const Icon(Icons.mic_rounded),
                          onPressed: () {},
                          color: Theme.of(context).primaryColor,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatService.getChatRoomStream(_chatEntityId),
      builder: (context, snapshot) {
        bool isReceiverTyping = false;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data.containsKey('typingStatus') &&
              data['typingStatus'].containsKey(widget.receiver!.uid)) {
            isReceiverTyping =
                data['typingStatus'][widget.receiver!.uid] ?? false;
          }
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isReceiverTyping ? 50 : 0,
          child: isReceiverTyping
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "typing...",
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }
}
