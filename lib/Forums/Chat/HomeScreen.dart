import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_list.dart';
import 'live_stream.dart';
import 'search_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _startPublicConsultation(BuildContext context) async {
    try {
      // Create a public consultation
      final currentUser = FirebaseAuth.instance.currentUser!;
      final chatId = 'public_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final consultationRef = FirebaseFirestore.instance.collection('Consultations').doc(chatId);
      await consultationRef.set({
        'chatId': chatId,
        'initiatorId': currentUser.uid,
        'recipientId': 'public', // Indicates open to all
        'status': 'active',
        'startTimestamp': FieldValue.serverTimestamp(),
      });

      // Navigate to LiveConsultationScreen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveConsultationScreen(
              channelName: chatId,
              isInitiator: true,
              chatId: chatId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting public consultation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start consultation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigation to login screen handled elsewhere
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ChatList(),
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('Consultations')
                .where('status', isEqualTo: 'active')
                .where('recipientId', isEqualTo: 'public')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                var consult = snapshot.data!.docs.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Public Consultation Available'),
                      content: const Text('A public consultation is active. Join now?'),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            var initiatorDoc = await FirebaseFirestore.instance
                                .collection('Users')
                                .doc(consult['initiatorId'])
                                .get();
                            var initiatorData = initiatorDoc.data() as Map<String, dynamic>;
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LiveConsultationScreen(
                                  channelName: consult['chatId'],
                                  isInitiator: false,
                                  chatId: consult['chatId'],
                                ),
                              ),
                            );
                          },
                          child: const Text('Join'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                });
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startPublicConsultation(context),
        child: const Icon(Icons.videocam),
        tooltip: 'Start Public Consultation',
      ),
    );
  }
}