import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final blockedSnapshot = await _firestore
          .collection('UserBlocks')
          .doc(currentUserId)
          .collection('blockedUsers')
          .orderBy('blockedAt', descending: true)
          .get();

      final blockedUsers = <Map<String, dynamic>>[];
      
      for (var doc in blockedSnapshot.docs) {
        final data = doc.data();
        blockedUsers.add({
          'userId': doc.id,
          'userName': data['blockedUserName'] ?? 'Unknown User',
          'blockedAt': data['blockedAt'],
        });
      }

      setState(() {
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading blocked users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Unblock User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unblock $userName?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (shouldUnblock == true) {
      try {
        await _firestore
            .collection('UserBlocks')
            .doc(currentUserId)
            .collection('blockedUsers')
            .doc(userId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName has been unblocked'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBlockedUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to unblock user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Blocked Users',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        'No blocked users',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Users you block will appear here',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  color: Colors.white,
                  backgroundColor: Colors.grey[900],
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blockedUsers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[850],
                            child: Icon(
                              Icons.person,
                              color: Colors.grey[400],
                            ),
                          ),
                          title: Text(
                            user['userName'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Blocked ${_formatDate(user['blockedAt'])}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () => _unblockUser(
                              user['userId'],
                              user['userName'],
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[850],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Unblock',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

