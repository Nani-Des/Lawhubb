import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nhap/widgets/profile_avatar.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/config_service.dart';

class LiveConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isInitiator;
  final String chatId;
  final String initiatorId;

  const LiveConsultationScreen({
    Key? key,
    required this.channelName,
    required this.isInitiator,
    required this.chatId,
    required this.initiatorId,
  }) : super(key: key);

  @override
  _LiveConsultationScreenState createState() => _LiveConsultationScreenState();
}

class _LiveConsultationScreenState extends State<LiveConsultationScreen> {
  static const String _kStreamViewersSubcollection = 'streamViewers';

  final ConfigService _configService = ConfigService();
  RtcEngine? _engine;

  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isEngineInitialized = false;
  bool _loading = true;
  bool _isDisposing = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;

  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  bool _showEmojiPicker = false;

  int _likes = 0;

  String initiatorName = "";
  String initiatorPic = "";

  /// Prevents double cleanup (back + dispose, or Firestore + user action).
  bool _exitInProgress = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _consultationSub;
  bool _viewerPresenceRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadInitiatorDetails();
    _listenForRemoteEnd();
    _setup();
  }

  void _listenForRemoteEnd() {
    _consultationSub = FirebaseFirestore.instance
        .collection('Consultations')
        .doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || _exitInProgress || !mounted) return;
      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String?;
      if (status != null && status != 'active') {
        unawaited(_leaveLiveStream(reason: 'remote_ended'));
      }
    });
  }

  Future<void> _loadInitiatorDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget.initiatorId)
          .get();
      if (doc.exists && mounted && !_isDisposing) {
        final data = doc.data() ?? {};
        setState(() {
          initiatorName = "${data['Fname'] ?? ''} ${data['Lname'] ?? ''}".trim();
          initiatorPic = data['User Pic'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error loading initiator: $e");
    }
  }

  Future<void> _setup() async {
    try {
      // Request permissions
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted && !_isDisposing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Camera & microphone permissions required"),
              backgroundColor: Colors.red,
            ),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
        return;
      }

      // Initialize Agora Engine
      final appId = _configService.agoraAppId;
      if (appId.isEmpty) {
        throw Exception('Agora App ID is not configured');
      }
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      
      if (_isDisposing) {
        await engine.release();
        return;
      }

      _engine = engine;
      _isEngineInitialized = true;

      // Register event handlers
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (!mounted || _isDisposing) return;
            setState(() => _localUserJoined = true);
            if (!widget.isInitiator) {
              unawaited(_registerViewerPresence());
              _checkForExistingBroadcaster();
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted || _isDisposing) return;
            if (widget.isInitiator) {
              // Broadcaster: optional UI refresh; viewer count comes from Firestore presence.
            } else {
              setState(() {
                _remoteUid = remoteUid;
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (!mounted || _isDisposing) return;
            if (widget.isInitiator) {
              // Presence docs remain accurate via viewer unregister on exit.
            } else {
              setState(() {
                _remoteUid = null;
              });
            }
          },
          onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
            if (!mounted || _isDisposing) return;
            // For viewers: detect when broadcaster's video becomes available
            if (!widget.isInitiator && state == RemoteVideoState.remoteVideoStateStarting) {
              setState(() {
                _remoteUid = remoteUid;
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            // Log only — avoid exposing Agora API messages in the UI.
            debugPrint("⚠️ Agora error: $err - $msg");
          },
        ),
      );

      // Enable video and audio
      await engine.enableVideo();
      await engine.enableAudio();

      // Set client role
      await engine.setClientRole(
        role: widget.isInitiator
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );

      // Start preview only for broadcaster
      if (widget.isInitiator) {
        await engine.startPreview();
      }

      // Join channel
      await engine.joinChannel(
        token: "",
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
    } catch (e) {
      debugPrint("⚠️ Agora init error: $e");
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to start the live stream. Check your connection and try again.',
            ),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposing) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _registerViewerPresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.isInitiator || _exitInProgress) return;
    try {
      await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .collection(_kStreamViewersSubcollection)
          .doc(uid)
          .set({
        'joinedAt': FieldValue.serverTimestamp(),
        'userId': uid,
      });
      _viewerPresenceRegistered = true;
    } catch (e) {
      debugPrint('Error registering viewer presence: $e');
    }
  }

  Future<void> _unregisterViewerPresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !_viewerPresenceRegistered) return;
    try {
      await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .collection(_kStreamViewersSubcollection)
          .doc(uid)
          .delete();
    } catch (e) {
      debugPrint('Error unregistering viewer presence: $e');
    }
    _viewerPresenceRegistered = false;
  }

  Future<void> _deleteAllViewerPresenceDocs() async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .collection(_kStreamViewersSubcollection)
          .get();
      var batch = FirebaseFirestore.instance.batch();
      var n = 0;
      for (final d in qs.docs) {
        batch.delete(d.reference);
        n++;
        if (n >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
    } catch (e) {
      debugPrint('Error clearing viewer presence: $e');
    }
  }

  // Check for existing broadcaster when viewer joins
  Future<void> _checkForExistingBroadcaster() async {
    if (widget.isInitiator || _isDisposing || !mounted) return;
    
    // Small delay to allow channel to fully initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_isDisposing || !mounted) return;
    
    // Try to get remote video state - if broadcaster is already streaming,
    // we should detect it via onRemoteVideoStateChanged
    // This is a fallback in case onUserJoined didn't fire
    try {
      // The onRemoteVideoStateChanged handler will catch when video becomes available
      // We just need to ensure we're listening properly
    } catch (e) {
      debugPrint("Error checking for broadcaster: $e");
    }
  }

  Future<void> _toggleMute() async {
    if (!_isEngineInitialized || _engine == null || !widget.isInitiator || _isDisposing) return;
    try {
      if (_isMuted) {
        await _engine!.enableLocalAudio(true);
        if (mounted && !_isDisposing) {
          setState(() => _isMuted = false);
        }
      } else {
        await _engine!.enableLocalAudio(false);
        if (mounted && !_isDisposing) {
          setState(() => _isMuted = true);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Toggle mute error: $e");
    }
  }

  Future<void> _toggleVideo() async {
    if (!_isEngineInitialized || _engine == null || !widget.isInitiator || _isDisposing) return;
    try {
      if (_isVideoEnabled) {
        await _engine!.enableLocalVideo(false);
        if (mounted && !_isDisposing) {
          setState(() => _isVideoEnabled = false);
        }
      } else {
        await _engine!.enableLocalVideo(true);
        if (mounted && !_isDisposing) {
          setState(() => _isVideoEnabled = true);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Toggle video error: $e");
    }
  }

  Future<void> _switchCamera() async {
    if (!_isEngineInitialized || _engine == null || !widget.isInitiator || _isDisposing) return;
    try {
      await _engine!.switchCamera();
    } catch (e) {
      debugPrint("⚠️ Switch camera error: $e");
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final text = _commentController.text.trim();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';
    
    _commentController.clear();
    
    try {
      // Save comment to Firestore
      await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .collection('comments')
          .add({
        'userId': userId,
        'userName': userName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Also add to local list for immediate UI update
      if (mounted && !_isDisposing) {
        setState(() {
          _comments.insert(0, {
            'text': text,
            'userName': userName,
            'timestamp': DateTime.now(),
          });
        });
      }
    } catch (e) {
      debugPrint("Error sending comment: $e");
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send comment: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Ends RTC session and updates Firestore. Call [popNavigator] false from [dispose].
  Future<void> _leaveLiveStream({
    String reason = 'user_left',
    bool popNavigator = true,
  }) async {
    if (_exitInProgress) return;
    _exitInProgress = true;
    _isDisposing = true;

    await _consultationSub?.cancel();
    _consultationSub = null;

    try {
      if (widget.isInitiator) {
        await _deleteAllViewerPresenceDocs();
        await FirebaseFirestore.instance
            .collection('Consultations')
            .doc(widget.chatId)
            .update({
          'status': 'ended',
          'viewerCount': 0,
          'endTimestamp': FieldValue.serverTimestamp(),
          'endReason': reason,
        });
      } else {
        await _unregisterViewerPresence();
      }
    } catch (e) {
      debugPrint('Firestore live exit error: $e');
    }

    try {
      if (_engine != null) {
        if (widget.isInitiator) {
          await _engine!.stopPreview();
        }
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
      }
    } catch (e) {
      debugPrint('Agora cleanup error: $e');
    }

    if (popNavigator && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  /// Cleanup without navigation — used when the widget is torn down (dispose / app background edge cases).
  Future<void> _silentDisposeCleanup() async {
    await _leaveLiveStream(
      reason: 'screen_disposed',
      popNavigator: false,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    if (!_exitInProgress) {
      _isDisposing = true;
      unawaited(_silentDisposeCleanup());
    }
    super.dispose();
  }

  Widget _renderVideo() {
    if (!_isEngineInitialized || _engine == null) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white70),
              SizedBox(height: 16),
              Text(
                "Connecting...",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isInitiator) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      if (_remoteUid != null && _localUserJoined) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return Container(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  initiatorName.isNotEmpty 
                      ? "Waiting for $initiatorName to start..."
                      : "Waiting for host...",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Widget _buildCommentsOverlay() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> comments = List.from(_comments);
        
        if (snapshot.hasData) {
          comments = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'text': data['text'] ?? '',
              'userName': data['userName'] ?? 'Anonymous',
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            };
          }).toList();
        }

        return Positioned(
          left: 10,
          bottom: 120,
          right: 10,
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                final text = comment['text'] as String;
                final clipped = text.length > 60 ? "${text.substring(0, 60)}..." : text;

                return TweenAnimationBuilder<double>(
                  key: ValueKey('${comment['timestamp']}_$text'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 20),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            clipped,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0.5, 0.5),
                                  blurRadius: 2,
                                )
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _commentController.text += emoji.emoji;
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() => _showEmojiPicker = !_showEmojiPicker);
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Add a comment...",
                          hintStyle: TextStyle(color: Colors.white54),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendComment,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required String tooltip,
    bool isEnabled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 24),
          onPressed: isEnabled ? onPressed : null,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildOverlayButtons() {
    return Positioned(
      top: 80,
      right: 16,
      child: SafeArea(
        child: Column(
          children: [
            // Viewer count — Firestore presence (accurate join/leave)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Consultations')
                    .doc(widget.chatId)
                    .collection(_kStreamViewersSubcollection)
                    .snapshots(),
                builder: (context, snap) {
                  final n = snap.hasData ? snap.data!.docs.length : 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$n',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Like button
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red, size: 24),
                onPressed: () {
                  setState(() => _likes++);
                  // Haptic feedback would be nice here
                },
                padding: const EdgeInsets.all(12),
              ),
            ),
            Text(
              '$_likes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0.5, 0.5),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            
            // Host controls
            if (widget.isInitiator && _localUserJoined) ...[
              const SizedBox(height: 16),
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                onPressed: _toggleMute,
                backgroundColor: _isMuted ? Colors.red : Colors.blueGrey[800]!,
                tooltip: _isMuted ? "Unmute" : "Mute",
              ),
              _buildControlButton(
                icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                onPressed: _toggleVideo,
                backgroundColor: _isVideoEnabled ? Colors.blueGrey[800]! : Colors.red,
                tooltip: _isVideoEnabled ? "Turn off camera" : "Turn on camera",
              ),
              _buildControlButton(
                icon: Icons.cameraswitch,
                onPressed: _switchCamera,
                backgroundColor: Colors.blueGrey[700]!,
                tooltip: "Switch camera",
              ),
              _buildControlButton(
                icon: Icons.call_end,
                onPressed: () async {
                  await _leaveLiveStream(reason: 'host_end_button');
                },
                backgroundColor: Colors.red,
                tooltip: "End stream",
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Connecting...",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _leaveLiveStream(reason: 'system_back');
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _renderVideo()),
          _buildCommentsOverlay(),
          _buildOverlayButtons(),
          _buildCommentInput(),
          
          // Top bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      await _leaveLiveStream(reason: 'back_button');
                    },
                  ),
                  const SizedBox(width: 8),
                  ProfileAvatar.circle(
                    imageUrl: initiatorPic,
                    radius: 20,
                    backgroundColor: Colors.grey[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          initiatorName.isNotEmpty ? initiatorName : "Loading...",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "LIVE",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
