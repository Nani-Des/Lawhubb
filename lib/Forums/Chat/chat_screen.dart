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
import '../../widgets/profile_avatar.dart';

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
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String? _localFilePath;
  /// After recording stops (preview before send).
  String? _pendingVoicePath;
  int _pendingVoiceDurationSec = 0;
  static const String _previewPlaybackId = '__local_preview__';
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
    _verifyChatAccess();
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
    try {
      _recorder.dispose();
    } catch (_) {}
    _deletePendingVoiceFileSync();
    messageController.dispose();
    super.dispose();
  }

  void _deletePendingVoiceFileSync() {
    final p = _pendingVoicePath;
    if (p == null) return;
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
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

  /// Ensures this thread id matches the two participants (WhatsApp-style 1:1).
  Future<void> _verifyChatAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final expectedId = uid.compareTo(widget.recipientId) < 0
        ? '${uid}_${widget.recipientId}'
        : '${widget.recipientId}_${uid}';
    if (widget.chatId != expectedId) {
      if (mounted) Navigator.maybePop(context);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('Chats')
        .doc(widget.chatId)
        .get();
    if (!mounted) return;
    if (!doc.exists) return;
    final parts = List<String>.from(doc.data()?['participants'] ?? []);
    if (parts.length != 2 ||
        !parts.contains(uid) ||
        !parts.contains(widget.recipientId)) {
      Navigator.maybePop(context);
    }
  }

  Future<void> _ensureChatRoomMetadata() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final other = widget.recipientId;
    final participants =
        uid.compareTo(other) < 0 ? [uid, other] : [other, uid];
    await FirebaseFirestore.instance
        .collection('Chats')
        .doc(widget.chatId)
        .set({
      'participants': participants,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
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

  /// Finishes recording and opens preview (send / discard / replay) instead of sending immediately.
  Future<void> _finishRecordingToPreview() async {
    try {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      setState(() => _isRecording = false);

      if (path == null || path.isEmpty) return;

      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing recorded.')),
          );
        }
        return;
      }

      var durationSec = _recordSeconds.clamp(0, 86400);
      if (durationSec < 1) durationSec = 1;

      try {
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(path);
        final d = _audioPlayer.duration;
        if (d != null && d.inMilliseconds > 0) {
          durationSec = d.inSeconds.clamp(1, 86400);
        }
      } catch (_) {}

      setState(() {
        _pendingVoicePath = path;
        _pendingVoiceDurationSec = durationSec;
        _localFilePath = null;
        _recordSeconds = 0;
        _willCancel = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        _willCancel = false;
      });
      _recordTimer?.cancel();
    }
  }

  Future<void> _discardVoicePreview() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _playingUrl = '';
    final path = _pendingVoicePath;
    setState(() {
      _pendingVoicePath = null;
      _pendingVoiceDurationSec = 0;
    });
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _togglePreviewPlayback() async {
    final path = _pendingVoicePath;
    if (path == null) return;
    try {
      if (_playingUrl == _previewPlaybackId && _audioPlayer.playing) {
        await _audioPlayer.pause();
        setState(() {});
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(path);
      _playingUrl = _previewPlaybackId;
      await _audioPlayer.play();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
  }

  Future<void> _sendPendingVoice() async {
    final path = _pendingVoicePath;
    final durationSec = _pendingVoiceDurationSec;
    if (path == null) return;

    try {
      await _audioPlayer.stop();
      _playingUrl = '';

      await _uploadAndSendVoiceFile(path, durationSec);

      setState(() {
        _pendingVoicePath = null;
        _pendingVoiceDurationSec = 0;
      });

      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send voice message: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSendVoiceFile(String path, int durationSec) async {
    final file = File(path);
    if (!await file.exists()) return;

    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_audios')
        .child(widget.chatId)
        .child(fileName);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    await _ensureChatRoomMetadata();

    await FirebaseFirestore.instance
        .collection('Chats')
        .doc(widget.chatId)
        .collection('Messages')
        .add({
      'content': '',
      'audioUrl': downloadUrl,
      'audioDurationSeconds': durationSec,
      'senderId': FirebaseAuth.instance.currentUser!.uid,
      'recipientId': widget.recipientId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': 'audio',
    });

    await FirebaseFirestore.instance.collection('Chats').doc(widget.chatId).update({
      'lastMessage': '[Voice message]',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Playback helpers with progress UI
  Future<void> _playAudioUrl(String url) async {
    try {
      if (_playingUrl == _previewPlaybackId) {
        await _audioPlayer.stop();
        _playingUrl = '';
      }
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

  int? _audioDurationFromMessage(Map<String, dynamic> message) {
    final v = message['audioDurationSeconds'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  Widget _buildAudioMessageWidget(String url, {int? storedDurationSec}) {
    final isPlaying = (_playingUrl == url && _audioPlayer.playing);
    final duration = _currentDuration;

    // Only show meaningful duration/position when playing the same url
    final showPosition = _playingUrl == url;
    final totalSeconds = storedDurationSec ?? duration.inSeconds;

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
                            showPosition && duration.inMilliseconds > 0
                                ? _formatDuration(_currentPosition.inSeconds)
                                : "00:00",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            showPosition && duration.inMilliseconds > 0
                                ? _formatDuration(_currentDuration.inSeconds)
                                : (totalSeconds > 0
                                    ? _formatDuration(totalSeconds)
                                    : '--:--'),
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
                _buildAudioMessageWidget(
                  message['audioUrl'] as String,
                  storedDurationSec: _audioDurationFromMessage(message),
                )
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
      _finishRecordingToPreview();
    }
  }

  // helper to start recording sequence (separated for clarity)
  void _startLocalRecordingSequence() {
    _startLocalRecording();
  }

  Widget _buildVoicePreviewBar() {
    final dur = _pendingVoiceDurationSec;
    final previewPlaying =
        _playingUrl == _previewPlaybackId && _audioPlayer.playing;
    final previewActive = _playingUrl == _previewPlaybackId;
    final durMs = _currentDuration.inMilliseconds;

    final String timeLine;
    if (previewActive && durMs > 0) {
      timeLine =
          '${_formatDuration(_currentPosition.inSeconds)} / ${_formatDuration(_currentDuration.inSeconds)}';
    } else {
      timeLine = _formatDuration(dur);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.grey[900],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Discard',
            onPressed: _discardVoicePreview,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        previewPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: _togglePreviewPlayback,
                      tooltip: previewPlaying ? 'Pause' : 'Play',
                    ),
                    Expanded(
                      child: Text(
                        timeLine,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (previewActive && durMs > 0)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: (_currentPosition.inMilliseconds / durMs)
                          .clamp(0.0, 1.0),
                      onChanged: (v) {
                        final ms = (v * durMs).toInt();
                        _audioPlayer.seek(Duration(milliseconds: ms));
                      },
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.tealAccent),
            tooltip: 'Send',
            onPressed: _sendPendingVoice,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Main background
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            ProfileAvatar.circle(
              imageUrl: widget.recipientPic,
              backgroundColor: Colors.grey[700],
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
                final uid = FirebaseAuth.instance.currentUser!.uid;
                final docs = snapshot.data!.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  final sid = m['senderId'] as String?;
                  final rid = m['recipientId'] as String?;
                  return sid == uid || rid == uid;
                }).toList();
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

          // Input row or voice preview
          _pendingVoicePath != null
              ? _buildVoicePreviewBar()
              : Container(
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
                      await _ensureChatRoomMetadata();
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
