// chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'consultation_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String recipientPic;
  final bool recipientRole;

  ChatScreen({
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPic,
    required this.recipientRole,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController messageController = TextEditingController();

  // Recording
  final Record _recorder = Record();
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String? _localFilePath;
  // Slide-to-cancel
  double _startLocalDx = 0.0;
  bool _willCancel = false;

  // Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  String _playingUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnline();
    _markMessagesAsRead(); // Mark messages as read when chat opens
    _durationSub = _audioPlayer.durationStream.listen((d) {
      if (d != null) setState(() => _currentDuration = d);
    });
    _positionSub = _audioPlayer.positionStream.listen((p) {
      setState(() => _currentPosition = p);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOffline();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    messageController.dispose();
    super.dispose();
  }

  // App lifecycle -> update presence
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _setUserOffline();
    }
  }

  Future<void> _setUserOnline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('Users').doc(uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Mark all messages in this chat as read
  Future<void> _markMessagesAsRead() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.chatId)
          .collection('Messages')
          .where('recipientId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in unreadMessages.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _setUserOffline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('Users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // Recording helpers
  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startLocalRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _localFilePath = path;
      await _recorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _willCancel = false;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(Duration(seconds: 1), (_) {
        setState(() => _recordSeconds++);
      });
    } else {
      // Optionally show a permission dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Microphone permission is required.')),
      );
    }
  }

  // Cancel local recording (delete file)
  Future<void> _cancelRecording() async {
    try {
      if (_isRecording) await _recorder.stop();
      _recordTimer?.cancel();
      if (_localFilePath != null) {
        final f = File(_localFilePath!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _localFilePath = null;
      _recordSeconds = 0;
      _willCancel = false;
    });
  }

  // Stop, upload and send
  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      setState(() => _isRecording = false);
      if (path == null) {
        // nothing recorded
        return;
      }
      final file = File(path);
      if (!await file.exists()) return;

      // Upload to Firebase Storage
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_audios')
          .child(widget.chatId)
          .child(fileName);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save message in Firestore
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.chatId)
          .collection('Messages')
          .add({
        'content': '',
        'audioUrl': downloadUrl,
        'senderId': FirebaseAuth.instance.currentUser!.uid,
        'recipientId': widget.recipientId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'audio',
      });

      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': '[Voice message]',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Optionally delete local temp file
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e) {
      // handle errors
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      setState(() => _isRecording = false);
      _recordTimer?.cancel();
    } finally {
      setState(() {
        _localFilePath = null;
        _recordSeconds = 0;
        _willCancel = false;
      });
    }
  }

  // Playback helpers with progress UI
  Future<void> _playAudioUrl(String url) async {
    try {
      if (_playingUrl == url && _audioPlayer.playing) {
        await _audioPlayer.pause();
        return;
      }
      if (_playingUrl != url) {
        await _audioPlayer.setUrl(url);
        _playingUrl = url;
      }
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Playback error: $e')));
    }
  }

  Widget _buildAudioMessageWidget(String url) {
    final isPlaying = (_playingUrl == url && _audioPlayer.playing);
    final position = _currentPosition;
    final duration = _currentDuration;

    // Only show meaningful duration/position when playing the same url
    final showPosition = _playingUrl == url;

    double sliderValue = 0.0;
    double max = 1.0;
    if (showPosition && duration.inMilliseconds > 0) {
      sliderValue = position.inMilliseconds / duration.inMilliseconds;
      max = 1.0;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white),
            onPressed: () async {
              await _playAudioUrl(url);
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slider
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    // allow seeking only if this is the playing url
                    if (_playingUrl == url && _currentDuration.inMilliseconds > 0) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final w = box.size.width;
                        final localDx = details.localPosition.dx.clamp(0.0, w);
                        final ratio = (localDx / w).clamp(0.0, 1.0);
                        final seekMs = (ratio * _currentDuration.inMilliseconds).toInt();
                        _audioPlayer.seek(Duration(milliseconds: seekMs));
                      }
                    }
                  },
                  child: Column(
                    children: [
                      Slider(
                        value: showPosition && duration.inMilliseconds > 0
                            ? (_currentPosition.inMilliseconds.clamp(0, _currentDuration.inMilliseconds) /
                            (_currentDuration.inMilliseconds == 0 ? 1 : _currentDuration.inMilliseconds))
                            : 0.0,
                        onChanged: showPosition && _currentDuration.inMilliseconds > 0
                            ? (v) {
                          final ms = (v * _currentDuration.inMilliseconds).toInt();
                          _audioPlayer.seek(Duration(milliseconds: ms));
                        }
                            : null,
                      ),
                      // times
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            showPosition
                                ? _formatDuration(_currentPosition.inSeconds)
                                : "00:00",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            showPosition
                                ? _formatDuration(_currentDuration.inSeconds)
                                : "--:--",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(DocumentSnapshot messageSnap) {
    final message = messageSnap.data() as Map<String, dynamic>;
    final isMe = message['senderId'] == FirebaseAuth.instance.currentUser!.uid;
    final type = (message['type'] ?? 'text') as String;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.redAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (type == 'text') ...[
              Text(
                message['content'] ?? '',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ] else if (type == 'audio') ...[
              if (message['audioUrl'] != null)
                _buildAudioMessageWidget(message['audioUrl'])
              else
                Text('Voice message', style: TextStyle(color: Colors.white)),
            ],
            SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message['timestamp'] != null
                      ? DateFormat('MMM d, HH:mm').format((message['timestamp'] as Timestamp).toDate())
                      : '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                if (isMe) ...[
                  SizedBox(width: 6),
                  Icon(
                    message['read'] == true ? Icons.done_all : Icons.done,
                    size: 16,
                    color: message['read'] == true ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Gesture helpers for the mic button (slide to cancel)
  void _onLongPressStart(LongPressStartDetails details) {
    _startLocalDx = details.globalPosition.dx;
    _startLocalRecordingSequence();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final dx = details.globalPosition.dx;
    final delta = _startLocalDx - dx; // positive when moving left
    // threshold in logical pixels
    if (delta > 100) {
      if (!_willCancel) {
        setState(() => _willCancel = true);
      }
    } else {
      if (_willCancel) {
        setState(() => _willCancel = false);
      }
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_willCancel) {
      _cancelRecording();
    } else {
      _stopAndSendRecording();
    }
  }

  // helper to start recording sequence (separated for clarity)
  void _startLocalRecordingSequence() {
    _startLocalRecording();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Main background
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.recipientPic.isNotEmpty ? NetworkImage(widget.recipientPic) : null,
              backgroundColor: Colors.grey[700],
              child: widget.recipientPic.isEmpty
                  ? Text(widget.recipientName[0], style: TextStyle(color: Colors.white, fontSize: 15))
                  : null,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName.length > 24 ? widget.recipientName.substring(0, 24) + "…" : widget.recipientName,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('Users').doc(widget.recipientId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Text("Offline", style: TextStyle(color: Colors.grey, fontSize: 12));
                      }
                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      final isOnline = userData['isOnline'] ?? false;
                      final lastSeen = userData['lastSeen'] as Timestamp?;
                      return Text(
                        isOnline ? "Online" : (lastSeen != null ? "Last seen: ${DateFormat('MMM d, HH:mm').format(lastSeen.toDate())}" : "Offline"),
                        style: TextStyle(color: isOnline ? Colors.redAccent : Colors.grey, fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Consultations')
                .doc(widget.chatId)
                .snapshots(),
            builder: (context, snapshot) {
              final currentUid = FirebaseAuth.instance.currentUser!.uid;

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  tooltip: "Start Video Consultation",
                  onPressed: currentUid != widget.recipientId
                      ? () async {
                          await FirebaseFirestore.instance
                              .collection('Consultations')
                              .doc(widget.chatId)
                              .set({
                            'chatId': widget.chatId,
                            'initiatorId': currentUid,
                            'recipientId': widget.recipientId,
                            'status': 'active',
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConsultationScreen(
                                  channelName: widget.chatId,
                                  isInitiator: true,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                );
              }

              final consultData =
                  snapshot.data!.data() as Map<String, dynamic>;
              if (consultData['status'] == 'active') {
                return IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.greenAccent),
                  tooltip: "Join Video Consultation",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConsultationScreen(
                          channelName: widget.chatId,
                          isInitiator: consultData['initiatorId'] == currentUid,
                        ),
                      ),
                    );
                  },
                );
              }

              return IconButton(
                icon: const Icon(Icons.videocam, color: Colors.white),
                tooltip: "Start Video Consultation",
                onPressed: currentUid != widget.recipientId
                    ? () async {
                        await FirebaseFirestore.instance
                            .collection('Consultations')
                            .doc(widget.chatId)
                            .set({
                          'chatId': widget.chatId,
                          'initiatorId': currentUid,
                          'recipientId': widget.recipientId,
                          'status': 'active',
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConsultationScreen(
                                channelName: widget.chatId,
                                isInitiator: true,
                              ),
                            ),
                          );
                        }
                      }
                    : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Chats')
                  .doc(widget.chatId)
                  .collection('Messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(docs[index]);
                  },
                );
              },
            ),
          ),

          // Input Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[900],
            child: Row(
              children: [
                // Mic (hold to record; slide left to cancel)
                GestureDetector(
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: _onLongPressMoveUpdate,
                  onLongPressEnd: _onLongPressEnd,
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: _willCancel ? Colors.redAccent : (_isRecording ? Colors.red : Colors.teal),
                    child: _isRecording
                        ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 18),
                        SizedBox(height: 2),
                        Text(
                          _formatDuration(_recordSeconds),
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                        : Icon(Icons.mic_none, color: Colors.white),
                  ),
                ),

                SizedBox(width: 8),

                // Message text input
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),

                SizedBox(width: 6),

                // Send button
                CircleAvatar(
                  backgroundColor: Colors.black12,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () async {
                      final text = messageController.text.trim();
                      if (text.isEmpty) return;
                      await FirebaseFirestore.instance
                          .collection('Chats')
                          .doc(widget.chatId)
                          .collection('Messages')
                          .add({
                        'content': text,
                        'senderId': FirebaseAuth.instance.currentUser!.uid,
                        'recipientId': widget.recipientId,
                        'timestamp': FieldValue.serverTimestamp(),
                        'read': false,
                        'type': 'text',
                      });
                      await FirebaseFirestore.instance.collection('Chats').doc(widget.chatId).update({
                        'lastMessage': text,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      messageController.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
