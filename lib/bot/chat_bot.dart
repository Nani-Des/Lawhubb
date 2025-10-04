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

  void _sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      if (_guestMessages.isNotEmpty || ChatService.getMessagesStream() == null) {
        _guestMessages.add({"role": "user", "text": query});
      }
    });

    _messageController.clear();

    await ChatService.saveMessage("user", query);

    // Get AI response
    String response = await OpenAIService.sendMessage(query);
    await ChatService.saveMessage("bot", response);

    if (ChatService.getMessagesStream() == null) {
      setState(() {
        _guestMessages.add({"role": "bot", "text": response});
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
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
            icon: const Icon(Icons.delete),
            onPressed: () async {
              if (chatStream == null) {
                // Clear guest chat
                await ChatService.clearLocalMessages();
                setState(() => _guestMessages.clear());
              }
              // For logged-in users you could also add Firestore chat clearing if needed
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatStream != null
                ? StreamBuilder<QuerySnapshot>(
              stream: chatStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return _buildMessageList(
                  docs.map((d) => d.data() as Map<String, dynamic>).toList(),
                );
              },
            )
                : _buildMessageList(_guestMessages),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Map<String, dynamic>> messages) {
    return ListView.builder(
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

        return Align(
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
                )
              ],
            ),
            child: Text(
              msg["text"] ?? "",
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
