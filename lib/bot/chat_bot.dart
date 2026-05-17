import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/bot/widget/chat_service.dart';
import 'package:nhap/bot/widget/openai_service.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:nhap/widgets/formatted_message_text.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _guestMessages = [];

  @override
  void initState() {
    super.initState();
    _loadGuestMessages();
  }

  Future<void> _loadGuestMessages() async {
    final msgs = await ChatService.getLocalMessages();
    setState(() => _guestMessages = msgs);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isLoading = true;
      _guestMessages.add({"role": "user", "text": trimmed});
    });

    _messageController.clear();
    await ChatService.saveMessage("user", trimmed);

    try {
      final response = await OpenAIService.sendMessage(trimmed);
      await ChatService.saveMessage("bot", response);
      if (!mounted) return;
      setState(() {
        _guestMessages.add({"role": "bot", "text": response});
      });
    } catch (e) {
      const fallback = OpenAIService.unavailableMessage;
      await ChatService.saveMessage("bot", fallback);
      if (!mounted) return;
      setState(() {
        _guestMessages.add({"role": "bot", "text": fallback});
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _deleteMessage(int index, {String? docId}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete message?"),
        content: const Text("This message will be removed permanently."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (docId != null) {
      // Logged-in user deletion
      final userId = ChatService.userId;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection("Chats")
            .doc(userId)
            .collection("messages")
            .doc(docId)
            .delete();
      }
    } else {
      // Guest message deletion — no reload, just local removal
      setState(() {
        _guestMessages.removeAt(index);
      });
      await ChatService.clearLocalMessages();
      for (var m in _guestMessages) {
        await ChatService.saveMessage(m['role'], m['text']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatStream = ChatService.getMessagesStream();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("LawHubb Assistant"),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear all messages?'),
                  content: const Text(
                    'This removes your LawHubb Assistant conversation.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;

              if (chatStream == null) {
                await ChatService.clearLocalMessages();
                if (mounted) setState(() => _guestMessages.clear());
              } else {
                await ChatService.clearFirestoreMessages();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWalkthroughGrid(),
          Expanded(
            child: chatStream != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: chatStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      final messages = docs
                          .map((d) => {
                                "docId": d.id,
                                ...d.data() as Map<String, dynamic>
                              })
                          .toList();

                      return _buildMessageList(messages, isFirestore: true);
                    },
                  )
                : _buildMessageList(_guestMessages),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWalkthroughGrid() {
    final l10n = AppLocalizations.of(context);
    final guides = [
      {
        "title": l10n?.bookAppointment ?? 'Book Appointment',
        "icon": Icons.calendar_today,
        "query": l10n?.book_appointment ?? 'Book appointment'
      },
      {
        "title": l10n?.findLawyer ?? 'Find lawyer',
        "icon": Icons.person_search,
        "query": l10n?.type_of_lawyer ?? 'Type of lawyer'
      },
      {
        "title": l10n?.lawServices ?? 'Law services',
        "icon": Icons.local_hospital,
        "query": l10n?.services_provided ?? 'Services provided'
      },
      {
        "title": l10n?.help ?? 'Help',
        "icon": Icons.warning,
        "query": l10n?.sue_someone ?? 'Help me sue someone'
      },
    ];

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3,
        ),
        itemCount: guides.length,
        itemBuilder: (context, index) {
          final guide = guides[index];
          return GestureDetector(
            onTap: () => _sendMessage(guide["query"] as String),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black26, width: 1),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(guide["icon"] as IconData, color: Colors.black87),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guide["title"] as String,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList(List<Map<String, dynamic>> messages,
      {bool isFirestore = false}) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LawHubb Assistant is typing…',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final msg = messages[index];
        final isUser = msg["role"] == "user";
        final docId = isFirestore ? msg["docId"] as String : null;

        return GestureDetector(
          onLongPress: () => _deleteMessage(index, docId: docId),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.85,
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.black87 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUser ? Colors.black : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser)
                    const Text("🤖 ", style: TextStyle(fontSize: 16)),
                  Flexible(
                    child: FormattedMessageBody(
                      text: msg["text"]?.toString() ?? "",
                      textColor: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      enableMarkdown: !isUser,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: "Ask LawHubb Assistant...",
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      key: ValueKey(_isListening),
                      color: Colors.black54,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _isListening = !_isListening);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: _isLoading
                ? null
                : () => _sendMessage(_messageController.text),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
