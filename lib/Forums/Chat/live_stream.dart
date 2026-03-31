import 'dart:async';
import 'package:flutter/material.dart';
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
  bool _hasLiked = false;
  int _viewerCount = 1;
  Timer? _viewerCountTimer;
  Timer? _viewerTimeoutTimer;
  bool _showComments = true;

  String initiatorName = "";
  String initiatorPic = "";

  @override
  void initState() {
    super.initState();
    _loadInitiatorDetails();
    _setup();
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
            if (widget.isInitiator) {
              _startViewerCountSync();
            } else {
              _checkForExistingBroadcaster();
              // Auto-exit if host never appears within 45 seconds
              _viewerTimeoutTimer = Timer(const Duration(seconds: 45), () {
                if (!mounted || _isDisposing || _remoteUid != null) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Host hasn't joined yet. Leaving stream."),
                    backgroundColor: Colors.orange,
                  ),
                );
                Navigator.pop(context);
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted || _isDisposing) return;
            if (widget.isInitiator) {
              // Broadcaster: someone (viewer) joined
              setState(() {
                _viewerCount++;
              });
              _updateViewerCount();
            } else {
              // Viewer: broadcaster joined — cancel the timeout
              _viewerTimeoutTimer?.cancel();
              setState(() {
                _remoteUid = remoteUid;
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (!mounted || _isDisposing) return;
            if (widget.isInitiator) {
              // Broadcaster: viewer left
              setState(() {
                _viewerCount = (_viewerCount > 1) ? _viewerCount - 1 : 1;
              });
              _updateViewerCount();
            } else {
              // Viewer: broadcaster left
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
            debugPrint("⚠️ Agora error: $err - $msg");
            if (mounted && !_isDisposing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
              );
            }
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
          SnackBar(
            content: Text("Failed to start live consultation: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposing) {
        setState(() => _loading = false);
      }
    }
  }

  void _startViewerCountSync() {
    _viewerCountTimer?.cancel();
    _viewerCountTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isDisposing || !mounted) {
        timer.cancel();
        return;
      }
      _updateViewerCount();
    });
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

  Future<void> _updateViewerCount() async {
    if (!widget.isInitiator || _isDisposing) return;
    try {
      await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .update({'viewerCount': _viewerCount});
    } catch (e) {
      debugPrint("Error updating viewer count: $e");
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

  Future<void> _endStreamCleanup() async {
    if (_isDisposing) return;
    _isDisposing = true;

    _viewerCountTimer?.cancel();
    _viewerTimeoutTimer?.cancel();

    try {
      if (widget.isInitiator) {
        await FirebaseFirestore.instance
            .collection('Consultations')
            .doc(widget.chatId)
            .update({
          'status': 'ended',
          'viewerCount': _viewerCount,
          'endTimestamp': FieldValue.serverTimestamp(),
        });
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('Consultations')
            .doc(widget.chatId)
            .get();
        if (snapshot.exists) {
          final currentCount = snapshot.data()?['viewerCount'] ?? 0;
          await FirebaseFirestore.instance
              .collection('Consultations')
              .doc(widget.chatId)
              .update({
            'viewerCount': (currentCount > 0) ? currentCount - 1 : 0,
          });
        }
      }
    } catch (e) {
      debugPrint("Error updating consultation status: $e");
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
      debugPrint("Error cleaning up Agora engine: $e");
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    _viewerCountTimer?.cancel();
    _viewerTimeoutTimer?.cancel();
    _commentController.dispose();
    // Always mark the stream as ended in Firestore when the widget is disposed,
    // even if the user force-closed the app and came back.
    if (widget.isInitiator) {
      FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .update({
        'status': 'ended',
        'endTimestamp': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    if (_engine != null) {
      _engine!.leaveChannel().catchError((_) {});
      _engine!.release().catchError((_) {});
      _engine = null;
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
      if (!_isVideoEnabled) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: initiatorPic.isNotEmpty
                      ? NetworkImage(initiatorPic)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: initiatorPic.isEmpty
                      ? const Icon(Icons.person, size: 48, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Camera is off',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
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
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.3),
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
              Colors.black.withOpacity(0.8),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
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
              color: Colors.black.withOpacity(0.4),
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
            // Viewer count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$_viewerCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Like button
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: Icon(
                  _hasLiked ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    if (_hasLiked) {
                      _likes = (_likes > 0) ? _likes - 1 : 0;
                      _hasLiked = false;
                    } else {
                      _likes++;
                      _hasLiked = true;
                    }
                  });
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
                  final shouldEnd = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text("End Live Consultation?", style: TextStyle(color: Colors.white)),
                      content: const Text("Are you sure you want to end this live consultation?", style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("End", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (shouldEnd == true) {
                    await _endStreamCleanup();
                  }
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _renderVideo()),
          if (_showComments) _buildCommentsOverlay(),
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
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      if (widget.isInitiator) {
                        final shouldEnd = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: const Text("End Live Consultation?", style: TextStyle(color: Colors.white)),
                            content: const Text("Are you sure you want to end this live consultation?", style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("End", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (shouldEnd == true) {
                          await _endStreamCleanup();
                        }
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: initiatorPic.isNotEmpty
                        ? NetworkImage(initiatorPic)
                        : null,
                    backgroundColor: Colors.grey[700],
                    child: initiatorPic.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          initiatorName.isNotEmpty ? initiatorName : 'Loading...',
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
                  // Comments toggle button
                  IconButton(
                    icon: Icon(
                      _showComments
                          ? Icons.chat_bubble
                          : Icons.chat_bubble_outline,
                      color: Colors.white70,
                    ),
                    tooltip: _showComments ? 'Hide comments' : 'Show comments',
                    onPressed: () =>
                        setState(() => _showComments = !_showComments),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
