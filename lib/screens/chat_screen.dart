import 'dart:async';
import 'dart:io';

import 'package:dynamichatapp/models/message.dart';
import 'package:dynamichatapp/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_profile.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final UserProfile receiver;
  ChatScreen({super.key, required this.receiver});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  Timer? _typingTimer;
  late String _chatRoomId;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  Message? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    List<String> ids = [
      _authService.getCurrentUser()!.uid,
      widget.receiver.uid,
    ];
    ids.sort();
    _chatRoomId = ids.join('_');

    _messageController.addListener(_onTyping);

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _onTyping() {
    final currentUser = _authService.getCurrentUser()!;

    _typingTimer?.cancel();

    if (_messageController.text.isNotEmpty) {
      _chatService.updateTypingStatus(_chatRoomId, currentUser.uid, true);
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }

    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTypingStatus(_chatRoomId, currentUser.uid, false);
    });
  }

  void _showReactionsDialog(String messageId) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: reactions
              .map(
                (emoji) => GestureDetector(
                  onTap: () {
                    _chatService.toggleMessageReaction(
                      _chatRoomId,
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
      ),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping);
    _typingTimer?.cancel();
    _fabAnimationController.dispose();
    _chatService.updateTypingStatus(
      _chatRoomId,
      _authService.getCurrentUser()!.uid,
      false,
    );
    super.dispose();
    _audioRecorder.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission is required.")),
      );
      return;
    }

    final Directory tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/audio_message.m4a';

    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null) {
      await _chatService.sendMessage(
        widget.receiver.uid,
        audioUrl: await _storageService.uploadAudioMessage(path, _chatRoomId),
        repliedToMessage: _replyingToMessage,
      );
      setState(() {
        _replyingToMessage = null;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
        widget.receiver.uid,
        text: _messageController.text,
        repliedToMessage: _replyingToMessage,
      );
      _messageController.clear();
      _fabAnimationController.reverse();
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
      List<String> ids = [
        _authService.getCurrentUser()!.uid,
        widget.receiver.uid,
      ];
      ids.sort();
      String chatRoomId = ids.join('_');

      final imageUrl = await _storageService.uploadChatImage(image, chatRoomId);

      if (imageUrl != null) {
        await _chatService.sendMessage(widget.receiver.uid, imageUrl: imageUrl);
      }
    }
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
            title: Row(
              children: [
                Hero(
                  tag: 'avatar_${widget.receiver.uid}',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: widget.receiver.photoURL != null
                          ? CachedNetworkImageProvider(
                              widget.receiver.photoURL!,
                            )
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: widget.receiver.photoURL == null
                          ? Text(
                              widget.receiver.email[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.receiver.email.split('@')[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Online',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _chatService.getChatRoomStream(_chatRoomId),
        builder: (context, snapshot) {
          bool isReceiverTyping = false;
          if (snapshot.hasData && snapshot.data!.data() != null) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (data.containsKey('typingStatus') &&
                data['typingStatus'].containsKey(widget.receiver.uid)) {
              isReceiverTyping =
                  data['typingStatus'][widget.receiver.uid] ?? false;
            }
          }

          return Column(
            children: [
              Expanded(child: _buildMessageList()),
              AnimatedContainer(
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundImage:
                                        widget.receiver.photoURL != null
                                        ? CachedNetworkImageProvider(
                                            widget.receiver.photoURL!,
                                          )
                                        : null,
                                    backgroundColor: Colors.grey[400],
                                    child: widget.receiver.photoURL == null
                                        ? Text(
                                            widget.receiver.email[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'typing...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              _buildMessageInput(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    String senderId = _authService.getCurrentUser()!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(widget.receiver.uid, senderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Something went wrong",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: snapshot.data!.docs
              .map((doc) => _buildMessageItem(doc))
              .toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    final messageId = doc.id;
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final message = Message.fromMap(data);
    final currentUserId = _authService.getCurrentUser()!.uid;
    bool isCurrentUser = message.senderId == _authService.getCurrentUser()!.uid;

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
            onLongPress: () => _showReactionsDialog(messageId),
            isReply: message.isReply,
            replyingToMessage: message.replyingToMessage,
            replyingToSender: message.replyingToSender,
            onReply: () {
              setState(() {
                _replyingToMessage = message;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Text(
              formattedTime,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildMessageInput(BuildContext context) {
  //   return Container(
  //     padding: const EdgeInsets.all(16.0),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, -2),
  //         ),
  //       ],
  //     ),
  //     child: SafeArea(
  //       child: Row(
  //         children: [

  //           Container(
  //             decoration: BoxDecoration(
  //               color: Theme.of(context).primaryColor.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: IconButton(
  //               icon: Icon(
  //                 Icons.add_photo_alternate_rounded,
  //                 color: Theme.of(context).primaryColor,
  //               ),
  //               onPressed: _sendImage,
  //             ),
  //           ),
  //           const SizedBox(width: 12),
  //           Expanded(
  //             child: Container(
  //               decoration: BoxDecoration(
  //                 color: Colors.grey[100],
  //                 borderRadius: BorderRadius.circular(25),
  //                 border: Border.all(color: Colors.grey[300]!),
  //               ),
  //               child: TextField(
  //                 controller: _messageController,
  //                 decoration: InputDecoration(
  //                   hintText: 'Type a message...',
  //                   hintStyle: TextStyle(color: Colors.grey[500]),
  //                   border: InputBorder.none,
  //                   contentPadding: const EdgeInsets.symmetric(
  //                     horizontal: 20,
  //                     vertical: 12,
  //                   ),
  //                 ),
  //                 onSubmitted: (_) => _sendMessage(),
  //                 maxLines: 3,
  //                 minLines: 1,
  //               ),
  //             ),
  //           ),
  //           const SizedBox(width: 12),
  //           ScaleTransition(
  //             scale: _fabAnimation,
  //             child: Container(
  //               decoration: BoxDecoration(
  //                 gradient: LinearGradient(
  //                   colors: [
  //                     Theme.of(context).primaryColor,
  //                     Theme.of(context).primaryColor.withOpacity(0.8),
  //                   ],
  //                 ),
  //                 borderRadius: BorderRadius.circular(12),
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: Theme.of(context).primaryColor.withOpacity(0.3),
  //                     blurRadius: 8,
  //                     offset: const Offset(0, 2),
  //                   ),
  //                 ],
  //               ),
  //               child: IconButton(
  //                 icon: const Icon(Icons.send_rounded, color: Colors.white),
  //                 onPressed: _sendMessage,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // In lib/screens/chat_screen.dart -> _ChatScreenState class

  Widget _buildMessageInput(BuildContext context) {
    // Check if the text field is empty to decide which button to show
    final isTextFieldEmpty = _messageController.text.isEmpty;

    return Column(
      children: [
        // 1. The "Replying to..." banner (if active)
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
                  onPressed: () {
                    setState(() {
                      _replyingToMessage = null;
                    });
                  },
                ),
              ],
            ),
          ),

        // 2. The "Recording..." indicator (if active)
        if (_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.red.withOpacity(0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  "Recording audio...",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // 3. The main message input bar
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
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.add_photo_alternate_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: _sendImage,
                  ),
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

                // 4. The conditional Send / Microphone button
                if (isTextFieldEmpty)
                  // Show Microphone button
                  GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressEnd: (details) => _stopRecordingAndSend(),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.mic_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                    ),
                  )
                else
                  // Show Send button
                  ScaleTransition(
                    scale: _fabAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildMessageInput(BuildContext context) {
  //   final isTextFieldEmpty = _messageController.text.isEmpty;
  //   return Column(
  //     children: [
  //       if (_replyingToMessage != null)
  //         if (_isRecording)
  //           Container(
  //             padding: const EdgeInsets.all(16),
  //             color: Colors.red.withOpacity(0.1),
  //             child: const Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Icon(Icons.mic, color: Colors.red),
  //                 SizedBox(width: 8),
  //                 Text("Recording...", style: TextStyle(color: Colors.red)),
  //               ],
  //             ),
  //           ),
  //       Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //         decoration: BoxDecoration(
  //           color: Theme.of(context).primaryColor.withOpacity(0.1),
  //           border: Border(top: BorderSide(color: Colors.grey[300]!)),
  //         ),
  //         child: Row(
  //           children: [
  //             Icon(
  //               Icons.reply,
  //               size: 20,
  //               color: Theme.of(context).primaryColor,
  //             ),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     "Replying to ${_replyingToMessage!.senderEmail.split('@')[0]}",
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.bold,
  //                       color: Theme.of(context).primaryColor,
  //                       fontSize: 13,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 2),
  //                   Text(
  //                     _replyingToMessage!.type == 'image'
  //                         ? 'An image'
  //                         : _replyingToMessage!.message,
  //                     maxLines: 1,
  //                     overflow: TextOverflow.ellipsis,
  //                     style: TextStyle(color: Colors.grey[700], fontSize: 13),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             IconButton(
  //               icon: const Icon(Icons.close, size: 20),
  //               onPressed: () {
  //                 setState(() {
  //                   _replyingToMessage = null; // Clear the reply state
  //                 });
  //               },
  //             ),
  //           ],
  //         ),
  //       ),

  //       Container(
  //         padding: const EdgeInsets.all(16.0),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.05),
  //               blurRadius: 10,
  //               offset: const Offset(0, -2),
  //             ),
  //           ],
  //         ),
  //         child: SafeArea(
  //           child: Row(
  //             children: [
  //               Container(
  //                 decoration: BoxDecoration(
  //                   color: Theme.of(context).primaryColor.withOpacity(0.1),
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //                 child: IconButton(
  //                   icon: Icon(
  //                     Icons.add_photo_alternate_rounded,
  //                     color: Theme.of(context).primaryColor,
  //                   ),
  //                   onPressed: _sendImage,
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               Expanded(
  //                 child: Container(
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey[100],
  //                     borderRadius: BorderRadius.circular(25),
  //                     border: Border.all(color: Colors.grey[300]!),
  //                   ),
  //                   child: TextField(
  //                     controller: _messageController,
  //                     decoration: InputDecoration(
  //                       hintText: 'Type a message...',
  //                       hintStyle: TextStyle(color: Colors.grey[500]),
  //                       border: InputBorder.none,
  //                       contentPadding: const EdgeInsets.symmetric(
  //                         horizontal: 20,
  //                         vertical: 12,
  //                       ),
  //                     ),
  //                     onSubmitted: (_) => _sendMessage(),
  //                     maxLines: 3,
  //                     minLines: 1,
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               ScaleTransition(
  //                 scale: _fabAnimation,
  //                 child: Container(
  //                   decoration: BoxDecoration(
  //                     gradient: LinearGradient(
  //                       colors: [
  //                         Theme.of(context).primaryColor,
  //                         Theme.of(context).primaryColor.withOpacity(0.8),
  //                       ],
  //                     ),
  //                     borderRadius: BorderRadius.circular(12),
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: Theme.of(
  //                           context,
  //                         ).primaryColor.withOpacity(0.3),
  //                         blurRadius: 8,
  //                         offset: const Offset(0, 2),
  //                       ),
  //                     ],
  //                   ),
  //                   child: IconButton(
  //                     icon: const Icon(Icons.send_rounded, color: Colors.white),
  //                     onPressed: _sendMessage,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
}
