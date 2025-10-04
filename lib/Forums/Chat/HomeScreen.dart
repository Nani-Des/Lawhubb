import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Forums/Chat/search_screen.dart';
import '../../Home/Widgets/custom_bottom_navbar.dart';
import '../../Hospital/doctor_profile.dart';
import '../Public/forum.dart';
import 'chat_list.dart';
import 'live_stream.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _startPublicConsultation(BuildContext context) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final chatId =
          'public_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final fullName =
      "${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}".trim();
      final userPic = userData['User Pic'] ?? '';

      final consultationRef =
      FirebaseFirestore.instance.collection('Consultations').doc(chatId);

      await consultationRef.set({
        'chatId': chatId,
        'initiatorId': currentUser.uid,
        'initiatorName': fullName,
        'initiatorPic': userPic,
        'recipientId': 'public',
        'status': 'active',
        'viewerCount': 0,
        'startTimestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveConsultationScreen(
              channelName: chatId,
              isInitiator: true,
              chatId: chatId, initiatorId: currentUser.uid,

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
    final currentUser = FirebaseAuth.instance.currentUser!;
    final loggedInUserId = currentUser.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,

        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.chat, color: Colors.white), text: "Chats"),
              Tab(icon: Icon(Icons.forum, color: Colors.white), text: "Chat Room"),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DoctorProfileScreen(userId: loggedInUserId, isReferral: false),
                    ),
                  );
                },
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('Users')
                      .doc(currentUser.uid)
                      .get(),
                  builder: (context, snapshot) {
                    String? userPic;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                      snapshot.data!.data() as Map<String, dynamic>?;
                      userPic = data?['User Pic'];
                    }
                    return CircleAvatar(
                      radius: 18,
                      backgroundImage: userPic != null && userPic.isNotEmpty
                          ? NetworkImage(userPic)
                          : const AssetImage("assets/Images/placeholder.png")
                      as ImageProvider,
                    );
                  },
                ),
              ),
            ),
            IconButton(onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen()));
            }, icon: Icon(Icons.search, color: Colors.white))
          ],
        ),

        body: TabBarView(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 120,
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('Consultations')
                        .where('status', isEqualTo: 'active')
                        .where('recipientId', isEqualTo: 'public')
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(color: Colors.white));
                      }

                      final consults = snapshot.data!.docs;

                      if (consults.isEmpty) {
                        return const Center(
                          child: Text(
                            "No live consultations",
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: consults.length,
                        itemBuilder: (context, index) {
                          final consult = consults[index];
                          final initiatorId = consult['initiatorId'];

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('Users')
                                .doc(initiatorId)
                                .get(),
                            builder: (context, userSnap) {
                              if (userSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                );
                              }

                              if (!userSnap.hasData || !userSnap.data!.exists) {
                                return const SizedBox(
                                  width: 80,
                                  child: Center(
                                    child: Icon(Icons.person_off,
                                        size: 35, color: Colors.white70),
                                  ),
                                );
                              }

                              final userData = userSnap.data!.data()
                              as Map<String, dynamic>? ??
                                  {};
                              final fullName =
                              "${userData['Fname'] ?? ''} ${userData['Lname'] ?? ''}"
                                  .trim();
                              final userPic = userData['User Pic'] ?? '';
                              final isHost = initiatorId == currentUser.uid;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          LiveConsultationScreen(
                                            channelName: consult['chatId'],
                                            isInitiator: isHost,
                                            chatId: consult['chatId'],
                                            initiatorId: initiatorId,
                                          ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          CircleAvatar(
                                            radius: 35,
                                            backgroundImage: userPic.isNotEmpty
                                                ? NetworkImage(userPic)
                                                : null,
                                            backgroundColor: Colors.grey[300],
                                            child: userPic.isEmpty
                                                ? const Icon(Icons.person,
                                                size: 35, color: Colors.white)
                                                : null,
                                          ),
                                          Container(
                                            margin:
                                            const EdgeInsets.only(bottom: 2),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isHost
                                                  ? Colors.tealAccent[700]
                                                  : Colors.redAccent,
                                              borderRadius:
                                              BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              isHost ? "YOU" : "LIVE",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        fullName.isNotEmpty
                                            ? fullName.length > 24
                                            ? '${fullName.substring(0, 21)}...'
                                            : fullName
                                            : (isHost ? "You" : "Host"),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Expanded(child: ChatList()),
              ],
            ),
            Forum(userId: loggedInUserId),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.redAccent,
          onPressed: () => _startPublicConsultation(context),
          child: const Icon(Icons.videocam, color: Colors.white),
          tooltip: 'Start Public Consultation',
        ),

        bottomNavigationBar: CustomBottomNavBar(selectedIndex: 2),
      ),
    );
  }
}
