import 'package:dynamichatapp/shared/models/message.dart';
import 'package:dynamichatapp/shared/widgets/audio_player_bubble.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final String? imageUrl;
  final String type;
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final VoidCallback onLongPress;
  final bool isReply;
  final String? replyingToMessage;
  final String? replyingToSender;
  final VoidCallback onReply;

  final bool isGroupChat;
  final String? senderName;
  final String? senderPhotoURL;
  final int totalMembers;

  final bool isHighlighted;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.imageUrl,
    required this.type,
    required this.reactions,
    required this.currentUserId,
    required this.onLongPress,
    this.isReply = false,
    this.replyingToMessage,
    this.replyingToSender,
    required this.onReply,

    this.isGroupChat = false,
    this.senderName,
    this.senderPhotoURL,

    this.totalMembers = 0,

    this.isHighlighted = false,
  });

  Widget _buildReadReceipt(BuildContext context, Message message) {
    if (!isCurrentUser) return const SizedBox.shrink();

    final bool allRead = message.readBy.length >= totalMembers;
    final icon = allRead ? Icons.done_all : Icons.done;
    final color = allRead ? Colors.blue : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Icon(icon, size: 16, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (type == 'system') {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    final highlightDecoration = BoxDecoration(
      color: Theme.of(context).primaryColor.withOpacity(0.2),
      borderRadius: BorderRadius.circular(22),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: isHighlighted ? highlightDecoration : const BoxDecoration(),
      padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: Slidable(
        key: UniqueKey(),
        startActionPane: ActionPane(
          motion: const StretchMotion(),
          dismissible: DismissiblePane(onDismissed: () => onReply()),
          children: [
            SlidableAction(
              onPressed: (_) => onReply(),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              foregroundColor: Theme.of(context).primaryColor,
              icon: Icons.reply,
              label: 'Reply',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Row(
            // crossAxisAlignment: isCurrentUser
            //     ? CrossAxisAlignment.end
            //     : CrossAxisAlignment.start,
            mainAxisAlignment: isCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGroupChat && !isCurrentUser)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: senderPhotoURL != null
                      ? CachedNetworkImageProvider(senderPhotoURL!)
                      : null,
                  child: senderPhotoURL == null
                      ? Text(senderName?[0].toUpperCase() ?? 'U')
                      : null,
                ),
              if (isGroupChat && !isCurrentUser) const SizedBox(width: 8),

              Flexible(
                child: Column(
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Show sender's name in group chat
                    if (isGroupChat && !isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
                        child: Text(
                          senderName ?? "User",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    if (isReply) _buildQuotedReply(context),

                    if (type == 'image')
                      _buildImageBubble(context)
                    else if (type == 'audio')
                      _buildAudioBubble(context) // New condition
                    else
                      _buildTextBubble(context),

                    // type == 'image'
                    //     ? _buildImageBubble(context)
                    //     : _buildTextBubble(context),
                    if (reactions.isNotEmpty) _buildReactionsDisplay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioBubble(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // ... (copy decoration from _buildTextBubble)
      ),
      // child: AudioPlayerBubble(
      //   audioUrl: imageUrl!,
      //   isCurrentUser: isCurrentUser,
      // ),
    );
  }

  Widget _buildQuotedReply(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isCurrentUser ? 48 : 8,
        right: isCurrentUser ? 8 : 48,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isCurrentUser ? Theme.of(context).primaryColor : Colors.grey)
            .withOpacity(0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          left: BorderSide(
            color: (isCurrentUser
                ? Theme.of(context).primaryColor
                : Colors.grey),
            width: 4,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyingToSender ?? "User",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: (isCurrentUser
                  ? Theme.of(context).primaryColor
                  : Colors.grey[800]),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            replyingToMessage ?? "",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay() {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          final userReacted = entry.value.contains(currentUserId);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '$emoji $count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: userReacted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Widget _buildTextBubble(BuildContext context) {
  //   // We wrap the bubble in a Row to control its alignment and width.
  //   return Row(
  //     mainAxisSize:
  //         MainAxisSize.min, // The Row should only be as wide as its children
  //     mainAxisAlignment: isCurrentUser
  //         ? MainAxisAlignment.end
  //         : MainAxisAlignment.start,
  //     children: [
  //       Flexible(
  //         // Flexible allows the container to shrink and not force the Row to be full width.
  //         child: Container(
  //           // Your existing beautiful decoration for the bubble
  //           decoration: BoxDecoration(
  //             gradient: isCurrentUser
  //                 ? LinearGradient(
  //                     colors: [
  //                       Theme.of(context).primaryColor,
  //                       Theme.of(context).primaryColor.withOpacity(0.8),
  //                     ],
  //                     begin: Alignment.topLeft,
  //                     end: Alignment.bottomRight,
  //                   )
  //                 : LinearGradient(
  //                     colors: [Colors.white, Colors.grey[50]!],
  //                     begin: Alignment.topLeft,
  //                     end: Alignment.bottomRight,
  //                   ),
  //             borderRadius: BorderRadius.only(
  //               topLeft: const Radius.circular(20),
  //               topRight: const Radius.circular(20),
  //               bottomLeft: isCurrentUser
  //                   ? const Radius.circular(20)
  //                   : const Radius.circular(4),
  //               bottomRight: isCurrentUser
  //                   ? const Radius.circular(4)
  //                   : const Radius.circular(20),
  //             ),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: isCurrentUser
  //                     ? Theme.of(context).primaryColor.withOpacity(0.3)
  //                     : Colors.black.withOpacity(0.1),
  //                 blurRadius: 8,
  //                 offset: const Offset(0, 2),
  //               ),
  //             ],
  //             border: !isCurrentUser
  //                 ? Border.all(color: Colors.grey[200]!, width: 1)
  //                 : null,
  //           ),
  //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //           // We no longer need margins here as the alignment is handled by the Row.
  //           child: Text(
  //             message,
  //             style: TextStyle(
  //               color: isCurrentUser ? Colors.white : Colors.black87,
  //               fontSize: 16,
  //               fontWeight: FontWeight.w400,
  //               height: 1.4,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildTextBubble(BuildContext context) {
    // --- Start: New Mention Parsing Logic ---
    final List<TextSpan> textSpans = [];
    // This RegExp looks for the pattern generated by the flutter_mentions package.
    final RegExp mentionRegex = RegExp(r"\[__.*?__\]\(__(\w+)__\)");

    // We use splitMapJoin to separate the normal text from the mentions
    message.splitMapJoin(
      mentionRegex,
      onMatch: (m) {
        // This is a placeholder for the user's display name.
        // A full implementation would fetch the name based on the ID.
        final String displayName = m
            .group(0)!
            .split('__](')
            .first
            .replaceAll('[__', '');

        textSpans.add(
          TextSpan(
            text: '@$displayName', // Display the mention with an '@'
            style: TextStyle(
              color: isCurrentUser
                  ? Colors.cyanAccent
                  : Theme.of(context).primaryColorDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        return ""; // Return an empty string for the matched part
      },
      onNonMatch: (n) {
        // This is the normal text that is not a mention
        textSpans.add(TextSpan(text: n));
        return ""; // Return an empty string for the non-matched part
      },
    );
    // --- End: New Mention Parsing Logic ---

    // We wrap the bubble in a Row to control its alignment and width.
    return Row(
      mainAxisSize:
          MainAxisSize.min, // The Row should only be as wide as its children
      mainAxisAlignment: isCurrentUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          // Flexible allows the container to shrink and not force the Row to be full width.
          child: Container(
            // Your existing beautiful decoration for the bubble
            decoration: BoxDecoration(
              gradient: isCurrentUser
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.white, Colors.grey[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isCurrentUser
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isCurrentUser
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: isCurrentUser
                      ? Theme.of(context).primaryColor.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: !isCurrentUser
                  ? Border.all(color: Colors.grey[200]!, width: 1)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // We use RichText here instead of a simple Text widget
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
                children: textSpans,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBubble(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isCurrentUser ? 40 : 0,
        right: isCurrentUser ? 0 : 40,
        top: 4,
        bottom: 4,
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isCurrentUser
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isCurrentUser
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isCurrentUser
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isCurrentUser
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                placeholder: (context, url) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[300]!, Colors.grey[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loading image...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red[100]!, Colors.red[50]!],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[400],
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 100),
              ),
            ),
          ),
          if (isCurrentUser)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: const Radius.circular(20),
                    bottomRight: const Radius.circular(4),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
