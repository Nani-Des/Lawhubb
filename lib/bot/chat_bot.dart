import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/bot/widget/chat_service.dart';
import 'package:nhap/bot/widget/openai_service.dart';

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
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _guestMessages.add({"role": "user", "text": query});
    });

    _messageController.clear();
    await ChatService.saveMessage("user", query);

    // ✅ Only send to AI when necessary
    final response = await OpenAIService.sendMessage(query);
    await ChatService.saveMessage("bot", response);

    setState(() {
      _guestMessages.add({"role": "bot", "text": response});
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("LawHub Assistant"),
        backgroundColor: Colors.redAccent,
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
                    .map((d) => {"docId": d.id, ...d.data() as Map<String, dynamic>})
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
        "title": "Book Appointment",
        "icon": Icons.calendar_today,
        "query": "How do I book an appointment with a lawyer?"
      },
      {
        "title": "Find Lawyer",
        "icon": Icons.person_search,
        "query": "How do I know what type of lawyer I need?"
      },
      {
        "title": "Law Services",
        "icon": Icons.local_hospital,
        "query": "What services does the chamber of law provide?"
      },
      {
        "title": "Help",
        "icon": Icons.warning,
        "query": "What should I do when I want to sue someone?"
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
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(guide["icon"] as IconData, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      guide["title"] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              child: Text("LawHub Assistant is typing..."),
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
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.redAccent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) const Text("🤖 ", style: TextStyle(fontSize: 16)),
                  Flexible(
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
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
            color: Colors.grey.withOpacity(0.2),
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
                hintText: "Ask LawHub Assistant...",
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                suffixIcon: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      key: ValueKey(_isListening),
                      color: Colors.redAccent,
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
            backgroundColor: Colors.redAccent,
            elevation: 2,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
