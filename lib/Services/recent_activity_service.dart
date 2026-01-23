import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

enum ActivityType {
  booking,
  message,
  documentSaved,
  readingHistory,
}

class ActivityItem {
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? id; // For navigation
  final Map<String, dynamic>? metadata; // Additional data for navigation

  ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.id,
    this.metadata,
  });
}

class RecentActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ActivityItem>> getRecentActivities(String userId, {int limit = 5}) async {
    final activities = <ActivityItem>[];

    try {
      // 1. Get recent bookings
      final bookingsDoc = await _firestore.collection('Bookings').doc(userId).get();
      if (bookingsDoc.exists) {
        final bookings = bookingsDoc.data()?['Bookings'] as List? ?? [];
        for (var booking in bookings) {
          if (booking['date'] is Timestamp) {
            final date = (booking['date'] as Timestamp).toDate();
            // Only show upcoming or recent bookings (within last 7 days)
            if (date.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
              try {
                final doctorDoc = await _firestore
                    .collection('Users')
                    .doc(booking['doctorId'])
                    .get();
                final doctorName = doctorDoc.exists
                    ? '${doctorDoc.data()?['Fname'] ?? ''} ${doctorDoc.data()?['Lname'] ?? ''}'.trim()
                    : 'Lawyer';
                final status = booking['status'] ?? 'Pending';
                
                activities.add(ActivityItem(
                  type: ActivityType.booking,
                  title: status == 'Pending'
                      ? 'Consultation Scheduled'
                      : status == 'Active'
                          ? 'Consultation Confirmed'
                          : 'Consultation Update',
                  subtitle: 'With $doctorName - ${_formatDate(date)}',
                  timestamp: date,
                  id: userId,
                  metadata: {'booking': booking},
                ));
              } catch (e) {
                // Skip if doctor data can't be fetched
              }
            }
          }
        }
      }

      // 2. Get recent messages from Chats collection
      // Chats are stored as Chats/{chatId} with participants array and Messages subcollection
      try {
        // Get chats where user is a participant
        // Note: Can't use orderBy with arrayContains, so we'll get all and sort in memory
        final chatsSnapshot = await _firestore
            .collection('Chats')
            .where('participants', arrayContains: userId)
            .limit(30)
            .get();
        
        // Sort by timestamp in memory
        final sortedChats = chatsSnapshot.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['timestamp'] as Timestamp?;
            final bTime = b.data()['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
        
        for (var chatDoc in sortedChats.take(20)) {
          final chatData = chatDoc.data();
          final participants = (chatData['participants'] as List?) ?? [];
          if (participants.length < 2) continue;

          // Get the other participant
          final otherUserId = participants.firstWhere(
            (id) => id != userId,
            orElse: () => participants.first,
          );

          // Get recent unread messages for this user in this chat
          final messagesSnapshot = await _firestore
              .collection('Chats')
              .doc(chatDoc.id)
              .collection('Messages')
              .where('recipientId', isEqualTo: userId)
              .where('read', isEqualTo: false)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (messagesSnapshot.docs.isNotEmpty) {
            final message = messagesSnapshot.docs.first.data();
            final timestamp = message['timestamp'] as Timestamp?;
            final senderId = message['senderId'] as String?;

            if (timestamp != null && senderId != null) {
              try {
                final senderDoc = await _firestore.collection('Users').doc(senderId).get();
                String senderName = 'Someone';
                String senderPic = '';
                bool senderRole = false;
                if (senderDoc.exists) {
                  final senderData = senderDoc.data();
                  senderName = '${senderData?['Fname'] ?? ''} ${senderData?['Lname'] ?? ''}'.trim();
                  senderPic = senderData?['User Pic'] ?? '';
                  senderRole = senderData?['Role'] ?? false;
                  if (senderName.isEmpty) senderName = 'Someone';
                }

                activities.add(ActivityItem(
                  type: ActivityType.message,
                  title: 'New Message',
                  subtitle: 'From $senderName',
                  timestamp: timestamp.toDate(),
                  id: chatDoc.id,
                  metadata: {
                    'chatId': chatDoc.id,
                    'senderId': senderId,
                    'recipientId': userId,
                    'senderName': senderName,
                    'senderPic': senderPic,
                    'senderRole': senderRole,
                  },
                ));
              } catch (e) {
                // Skip if sender data can't be fetched
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching messages: $e');
      }

      // 3. Get saved documents from Hive (reading archive)
      try {
        final archiveBox = await Hive.openBox('reading_archive');
        final keys = archiveBox.keys.toList();
        final savedDocs = <Map<String, dynamic>>[];

        for (var key in keys) {
          final data = archiveBox.get(key);
          if (data is Map) {
            final timestamp = data['timestamp'];
            if (timestamp != null) {
              try {
                final date = DateTime.parse(timestamp);
                // Only show documents saved in last 7 days
                if (date.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
                  savedDocs.add({
                    'id': key,
                    'title': data['title'] ?? 'Untitled',
                    'timestamp': date,
                  });
                }
              } catch (e) {
                // Skip invalid timestamps
              }
            }
          }
        }

        savedDocs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
        
        for (var doc in savedDocs.take(2)) {
          activities.add(ActivityItem(
            type: ActivityType.documentSaved,
            title: 'Document Saved',
            subtitle: doc['title'] as String,
            timestamp: doc['timestamp'] as DateTime,
            id: doc['id'] as String,
            metadata: {'documentId': doc['id']},
          ));
        }
      } catch (e) {
        // Hive box might not be initialized, skip
      }

      // 4. Get reading history from Hive (recently read documents with progress)
      try {
        final archiveBox = await Hive.openBox('reading_archive');
        final keys = archiveBox.keys.toList();
        final readingHistory = <Map<String, dynamic>>[];

        for (var key in keys) {
          final data = archiveBox.get(key);
          if (data is Map) {
            final timestamp = data['timestamp'];
            final progress = data['progress'] as double? ?? 0.0;
            // Only show documents with progress (started but not finished)
            if (timestamp != null && progress > 0 && progress < 1.0) {
              try {
                final date = DateTime.parse(timestamp);
                // Only show recent reading (within last 3 days)
                if (date.isAfter(DateTime.now().subtract(const Duration(days: 3)))) {
                  readingHistory.add({
                    'id': key,
                    'title': data['title'] ?? 'Untitled',
                    'progress': progress,
                    'timestamp': date,
                  });
                }
              } catch (e) {
                // Skip invalid timestamps
              }
            }
          }
        }

        readingHistory.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
        
        for (var doc in readingHistory.take(2)) {
          final progressPercent = ((doc['progress'] as double) * 100).toInt();
          activities.add(ActivityItem(
            type: ActivityType.readingHistory,
            title: 'Continue Reading',
            subtitle: '${doc['title']} - $progressPercent% complete',
            timestamp: doc['timestamp'] as DateTime,
            id: doc['id'] as String,
            metadata: {'documentId': doc['id']},
          ));
        }
      } catch (e) {
        // Hive box might not be initialized, skip
      }

      // Sort all activities by timestamp (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Return limited results
      return activities.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching recent activities: $e');
      return [];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow ${_formatTime(date)}';
    } else if (difference.inDays == -1) {
      return 'Yesterday ${_formatTime(date)}';
    } else if (difference.inDays.abs() < 7) {
      return '${_getWeekday(date)} ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  String getTimeAgo(ActivityItem activity) {
    return _formatTimeAgo(activity.timestamp);
  }
}
