import 'dart:async';
import 'package:dynamichatapp/shared/models/group_profile.dart';
import 'package:dynamichatapp/shared/models/message.dart';
import 'package:dynamichatapp/features/group/group_info_screen.dart';
import 'package:dynamichatapp/shared/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/widgets/chat_bubble.dart';

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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  List<UserProfile> _mentionedUsers = [];

  Timer? _typingTimer;
  late String _chatEntityId;
  Message? _replyingToMessage;
  String? _highlightedMessageId;
  Timer? _highlightTimer;

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
    _highlightTimer?.cancel();
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

  void _jumpToMessage(
    String messageId,
    List<QueryDocumentSnapshot> currentMessages,
  ) {
    final index = currentMessages.indexWhere((doc) => doc.id == messageId);

    if (index != -1) {
      setState(() {
        _highlightedMessageId = messageId;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 100));

        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      });

      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Original message not found.")),
      );
    }
  }

  void _markVisibleMessagesAsRead(List<dynamic> messages) {
    for (var messageOrDoc in messages) {
      Message message;
      String messageId;

      if (messageOrDoc is QueryDocumentSnapshot) {
        final doc = messageOrDoc;
        message = Message.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        messageId = doc.id;
      } else if (messageOrDoc is Message) {
        message = messageOrDoc;
        messageId = message.id ?? '';
      } else {
        continue;
      }

      final isReadByCurrentUser = message.readBy.containsKey(
        _authService.getCurrentUser()!.uid,
      );

      if (message.senderId != _authService.getCurrentUser()!.uid &&
          !isReadByCurrentUser) {
        if (widget.isGroupChat) {
          _chatService.markGroupMessageAsRead(_chatEntityId, messageId);
        } else {
          _chatService.markPersonalMessageAsRead(_chatEntityId, messageId);
        }
      }
    }
  }

  void _markPersonalMessagesAsRead(List<Message> messages) {
    for (final message in messages) {
      final isReadByCurrentUser = message.readBy.containsKey(
        _authService.getCurrentUser()!.uid,
      );

      if (message.senderId != _authService.getCurrentUser()!.uid &&
          !isReadByCurrentUser) {
        _chatService.markPersonalMessageAsRead(_chatEntityId, message.id ?? '');
      }
    }
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) return;

    final List<String> mentionedUserIds =
        _mentionedUsers.map((user) => user.uid).toList();

    final receiverId =
        widget.isGroupChat ? widget.group!.groupId : widget.receiver!.uid;

    print('DEBUG: messageText = "$messageText"');
    print('DEBUG: mentionedUserIds = $mentionedUserIds');

    await _chatService.sendMessage(
      receiverId,
      isGroup: widget.isGroupChat,
      text: messageText,
      repliedToMessage: _replyingToMessage,
      mentionedUserIds: mentionedUserIds,
    );

    _messageController.clear();
    setState(() {
      _replyingToMessage = null;
      _mentionedUsers = [];
    });
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
        final receiverId =
            widget.isGroupChat ? widget.group!.groupId : widget.receiver!.uid;
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

  Widget _buildPinnedMessageBanner(
    GroupProfile group,
    List<QueryDocumentSnapshot> currentMessages,
  ) {
    if (group.pinnedMessage == null) {
      return const SizedBox.shrink();
    }

    final isAdmin = group.admins.contains(_authService.getCurrentUser()!.uid);
    final pinnedData = group.pinnedMessage!;
    final messageText =
        pinnedData['type'] == 'image' ? '📷 Image' : pinnedData['message'];

    return Material(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: InkWell(
        onTap: () {
          _jumpToMessage(pinnedData['messageId'], currentMessages);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 18, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pinned by ${pinnedData['senderName']}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      messageText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _chatService.unpinMessage(group),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionsDialog(Message message, String messageId) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    final isCurrentUser =
        message.senderId == _authService.getCurrentUser()!.uid;
    final bool isAdmin =
        widget.group?.admins.contains(_authService.getCurrentUser()!.uid) ??
            false;
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
                        if (widget.isGroupChat) {
                          _chatService.toggleGroupMessageReaction(
                            _chatEntityId,
                            messageId,
                            emoji,
                          );
                        } else {
                          _chatService.togglePersonalMessageReaction(
                            _chatEntityId,
                            messageId,
                            emoji,
                          );
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList(),
            ),
            if (widget.isGroupChat && isAdmin) const Divider(height: 24),
            if (widget.isGroupChat && isAdmin)
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text("Pin Message"),
                onTap: () {
                  Navigator.of(context).pop();
                  _chatService.pinMessage(widget.group!, message);
                },
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
          if (widget.isGroupChat)
            StreamBuilder<QuerySnapshot>(
              stream: _chatService.getGroupMessagesStream(_chatEntityId),
              builder: (context, msgSnapshot) {
                final messages = msgSnapshot.hasData
                    ? msgSnapshot.data!.docs
                    : <QueryDocumentSnapshot>[];
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.group!.groupId)
                      .snapshots(),
                  builder: (context, groupSnapshot) {
                    if (!groupSnapshot.hasData) return const SizedBox.shrink();
                    final updatedGroup = GroupProfile.fromDocument(
                      groupSnapshot.data!,
                    );
                    return _buildPinnedMessageBanner(updatedGroup, messages);
                  },
                );
              },
            ),
          Expanded(child: _buildMessageList()),
          if (!widget.isGroupChat) _buildTypingIndicator(),
          _buildMessageInput(context),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (widget.isGroupChat) {
      return StreamBuilder<List<Message>>(
        stream:
            _chatService.getGroupMessagesStreamWithDecryption(_chatEntityId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 3));
          }

          final messages = snapshot.data ?? [];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markVisibleMessagesAsRead(messages);
          });

          return ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _buildMessageItemFromMessage(message);
            },
          );
        },
      );
    } else {
      return StreamBuilder<List<Message>>(
        stream: _chatService.getMessagesStream(_chatEntityId, false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 3));
          }
          final messages = snapshot.data ?? [];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markPersonalMessagesAsRead(messages);
          });

          return ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _buildMessageItemFromMessage(message);
            },
          );
        },
      );
    }
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    final messageId = doc.id;

    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final message = Message.fromMap(
      doc.data() as Map<String, dynamic>,
      messageId,
    );
    final currentUserId = _authService.getCurrentUser()!.uid;
    bool isCurrentUser = message.senderId == currentUserId;
    var alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final formattedTime = DateFormat(
      'hh:mm a',
    ).format(message.timestamp.toDate());

    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            isHighlighted: message.id == _highlightedMessageId,
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

  Widget _buildMessageItemFromMessage(Message message) {
    final currentUserId = _authService.getCurrentUser()!.uid;
    bool isCurrentUser = message.senderId == currentUserId;
    var alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final formattedTime = DateFormat(
      'hh:mm a',
    ).format(message.timestamp.toDate());

    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: message.message,
            isCurrentUser: isCurrentUser,
            imageUrl: message.imageUrl,
            type: message.type,
            reactions: message.reactions,
            currentUserId: currentUserId,
            onLongPress: () => _showReactionsDialog(message, message.id ?? ''),
            isReply: message.isReply,
            replyingToMessage: message.replyingToMessage,
            replyingToSender: message.replyingToSender,
            onReply: () => setState(() => _replyingToMessage = message),
            isGroupChat: widget.isGroupChat,
            senderName: message.senderName,
            senderPhotoURL: message.senderPhotoURL,
            isHighlighted: message.id == _highlightedMessageId,
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

  Widget _buildReadReceipt(Message message) {
    if (message.senderId != _authService.getCurrentUser()!.uid)
      return const SizedBox.shrink();

    bool isSeenByReceiver;

    if (widget.isGroupChat) {
      final totalMembers = widget.group?.members.length ?? 0;
      isSeenByReceiver =
          totalMembers > 1 && message.readBy.length >= totalMembers;
    } else {
      isSeenByReceiver = message.readBy.containsKey(widget.receiver!.uid);
    }

    final icon = isSeenByReceiver ? Icons.done_all : Icons.done;
    final color = isSeenByReceiver ? Colors.blueAccent : Colors.grey;

    return GestureDetector(
      onTap: () {
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  onPressed: _sendImage,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.isGroupChat &&
                          _messageController.text.contains('@'))
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: FutureBuilder<List<UserProfile>>(
                            future: _getMentionSuggestions(
                              _messageController.text,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final user = snapshot.data![index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: user.photoURL != null
                                          ? CachedNetworkImageProvider(
                                              user.photoURL!,
                                            )
                                          : null,
                                      child: user.photoURL == null
                                          ? Text(user.email[0].toUpperCase())
                                          : null,
                                    ),
                                    title: Text(
                                      user.email.split('@')[0],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      user.email,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    onTap: () => _selectMention(user),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (text) => setState(() {}),
                        maxLines: 5,
                        minLines: 1,
                      ),
                    ],
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

  Future<List<UserProfile>> _getMentionSuggestions(String text) async {
    if (!widget.isGroupChat) return [];

    if (!text.contains('@')) return [];

    final lastAtIndex = text.lastIndexOf('@');
    if (lastAtIndex == -1) return [];

    final searchPattern = text.substring(lastAtIndex + 1).toLowerCase();

    final List<UserProfile> suggestions = [];
    for (final memberId in widget.group!.members) {
      if (memberId == _authService.getCurrentUser()!.uid) continue;

      try {
        final user = await _chatService.getUserProfile(memberId);
        if (user != null) {
          final displayName = user.email.split('@')[0].toLowerCase();
          if (searchPattern.isEmpty || displayName.contains(searchPattern)) {
            suggestions.add(user);
          }
        }
      } catch (e) {
        print('Error fetching user profile: $e');
      }
    }
    return suggestions;
  }

  void _selectMention(UserProfile user) {
    final currentText = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;

    final beforeCursor = currentText.substring(0, cursorPosition);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex != -1) {
      final newText = currentText.substring(0, atIndex) +
          '@${user.email.split('@')[0]} ' +
          currentText.substring(cursorPosition);

      _messageController.text = newText;

      final newCursorPosition = atIndex + user.email.split('@')[0].length + 2;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursorPosition),
      );

      if (!_mentionedUsers.contains(user)) {
        setState(() {
          _mentionedUsers.add(user);
        });
      }
    }
  }
}
