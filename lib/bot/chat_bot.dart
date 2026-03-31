import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/bot/widget/chat_service.dart';
import 'package:nhap/bot/widget/openai_service.dart';
import 'package:nhap/main.dart';

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
  String? _lastQuery;

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
    if (query.trim().isEmpty) return;

    _lastQuery = query;
    setState(() {
      _isLoading = true;
      _guestMessages.add({"role": "user", "text": query});
    });

    _messageController.clear();
    await ChatService.saveMessage("user", query);

    final response = await OpenAIService.sendMessage(query);
    final isError = response.startsWith("⚠️");
    await ChatService.saveMessage("bot", response);

    setState(() {
      _guestMessages.add({"role": "bot", "text": response, "isError": isError});
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _retryLastMessage() async {
    if (_lastQuery == null || _isLoading) return;
    // Remove the last error bot message
    if (_guestMessages.isNotEmpty && _guestMessages.last['isError'] == true) {
      setState(() => _guestMessages.removeLast());
    }
    setState(() => _isLoading = true);
    final response = await OpenAIService.sendMessage(_lastQuery!);
    final isError = response.startsWith("⚠️");
    await ChatService.saveMessage("bot", response);
    setState(() {
      _guestMessages.add({"role": "bot", "text": response, "isError": isError});
      _isLoading = false;
    });
    _scrollToBottom();
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
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("LawHub Assistant",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[900]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              if (chatStream == null) {
                await ChatService.clearLocalMessages();
                setState(() => _guestMessages.clear());
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
    final guides = [
      {
        "title": appLocalization!.bookAppointment,
        "icon": Icons.calendar_today,
        "query": appLocalization!.book_appointment
      },
      {
        "title": appLocalization!.findLawyer,
        "icon": Icons.person_search,
        "query": appLocalization!.type_of_lawyer
      },
      {
        "title": appLocalization!.lawServices,
        "icon": Icons.local_hospital,
        "query": appLocalization!.services_provided
      },
      {
        "title": appLocalization!.help,
        "icon": Icons.warning,
        "query": appLocalization!.sue_someone
      },
    ];

    return Container(
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
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(guide["icon"] as IconData, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guide["title"] as String,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
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
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("LawHub Assistant is typing...",
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          );
        }

        final msg = messages[index];
        final isUser = msg["role"] == "user";
        final isError = msg["isError"] == true;
        final docId = isFirestore ? msg["docId"] as String : null;
        final isLastMessage = index == messages.length - 1;

        return GestureDetector(
          onLongPress: () => _deleteMessage(index, docId: docId),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isError
                        ? Colors.red[900]
                        : isUser
                            ? Colors.white
                            : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isUser)
                        Text(isError ? "⚠️ " : "🤖 ",
                            style: const TextStyle(fontSize: 16)),
                      Flexible(
                        child: Text(
                          msg["text"] ?? "",
                          style: TextStyle(
                            color: isUser ? Colors.black87 : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isError && isLastMessage && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TextButton.icon(
                      onPressed: _retryLastMessage,
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                      label: const Text("Retry",
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ),
              ],
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
        color: const Color(0xFF111111),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.grey[900]!, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: null,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Ask LawHub Assistant...",
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                suffixIcon: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      key: ValueKey(_isListening),
                      color: Colors.grey[400],
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
            onPressed: () => _sendMessage(_messageController.text),
            backgroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.send, color: Colors.black, size: 20),
          ),
        ],
      ),
    );
  }
}
