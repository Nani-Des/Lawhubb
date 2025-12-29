import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class ConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isInitiator;

  const ConsultationScreen({
    required this.channelName,
    required this.isInitiator,
    Key? key,
  }) : super(key: key);

  @override
  _ConsultationScreenState createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  static const String _appId = "873c3e4a81ca45cb92806d6362381790";
  RtcEngine? _engine;

  bool _isJoined = false;
  int? _remoteUid;
  bool _isScreenSharing = false;
  bool _isEngineInitialized = false;
  bool _loading = true;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isDisposing = false;

  final TextEditingController _chatController = TextEditingController();
  final userId = FirebaseAuth.instance.currentUser!.uid;

  double previewX = 20;
  double previewY = 80;
  final double previewWidth = 130;
  final double previewHeight = 180;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      // Request permissions
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Camera & microphone permissions required"),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (mounted) {
          setState(() => _loading = false);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
        return;
      }

      // Initialize Agora Engine
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: _appId));
      
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
            setState(() => _isJoined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted || _isDisposing) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (!mounted || _isDisposing) return;
            setState(() => _remoteUid = null);
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("⚠️ Agora error: $err - $msg");
            if (mounted && !_isDisposing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
              );
            }
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint("Connection state changed: $state, reason: $reason");
          },
        ),
      );

      // Enable video and audio
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.startPreview();

      // Join channel
      await engine.joinChannel(
        token: "",
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      debugPrint("⚠️ Agora init error: $e");
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to start consultation: $e"),
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

  Future<void> _toggleMute() async {
    if (!_isEngineInitialized || _engine == null || _isDisposing) return;
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
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to toggle microphone: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleVideo() async {
    if (!_isEngineInitialized || _engine == null || _isDisposing) return;
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
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to toggle camera: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleScreenShare() async {
    if (!_isEngineInitialized || _engine == null || _isDisposing) return;
    try {
      if (_isScreenSharing) {
        await _engine!.stopScreenCapture();
        if (mounted && !_isDisposing) {
          setState(() => _isScreenSharing = false);
        }
      } else {
        await _engine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureAudio: true,
            captureVideo: true,
            videoParams: ScreenVideoParameters(
              dimensions: VideoDimensions(width: 1280, height: 720),
              frameRate: 15,
              bitrate: 800,
            ),
          ),
        );
        if (mounted && !_isDisposing) {
          setState(() => _isScreenSharing = true);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Screen share error: $e");
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Screen sharing not available: $e"), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _endConsultation() async {
    if (_isDisposing) return;
    _isDisposing = true;

    try {
      // Update Firestore status
      await FirebaseFirestore.instance
          .collection("Consultations")
          .doc(widget.channelName)
          .update({
        "status": "ended",
        "endTimestamp": FieldValue.serverTimestamp(),
      }).catchError((e) => debugPrint("Firestore update error: $e"));
    } catch (e) {
      debugPrint("Error updating consultation status: $e");
    }

    try {
      // Cleanup Agora engine
      if (_engine != null) {
        await _engine!.stopPreview();
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
    _chatController.dispose();
    _endConsultation();
    super.dispose();
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid != null && _isEngineInitialized && _engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 16),
            Text(
              "Waiting for participant...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPreview() {
    if (!_isEngineInitialized || _engine == null || !_isVideoEnabled) {
      return Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.videocam_off, color: Colors.white54, size: 40),
      );
    }

    return GestureDetector(
      onPanUpdate: (details) {
        if (!mounted) return;
        setState(() {
          previewX = (previewX + details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - previewWidth);
          previewY = (previewY + details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - previewHeight - 200);
        });
      },
      child: Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 5,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Chat messages
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("Consultations")
                      .doc(widget.channelName)
                      .collection("messages")
                      .orderBy("timestamp", descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      );
                    }
                    final messages = snapshot.data!.docs;
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          "No messages yet",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        final isMe = msg["senderId"] == userId;
                        final text = msg["text"] as String? ?? "";
                        final timestamp = msg["timestamp"] as Timestamp?;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blueGrey[800] : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (timestamp != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          color: (isMe ? Colors.white : Colors.white70).withOpacity(0.6),
                                          fontSize: 10,
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
                  },
                ),
              ),
              // Chat input
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border(
                    top: BorderSide(color: Colors.grey[800]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: TextStyle(color: Colors.white54),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[700],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: () async {
                          if (_chatController.text.trim().isEmpty) return;
                          final text = _chatController.text.trim();
                          _chatController.clear();
                          try {
                            await FirebaseFirestore.instance
                                .collection("Consultations")
                                .doc(widget.channelName)
                                .collection("messages")
                                .add({
                              "senderId": userId,
                              "text": text,
                              "timestamp": FieldValue.serverTimestamp(),
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to send message: $e"), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inDays < 1) {
      return "${difference.inHours}h ago";
    } else {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required String tooltip,
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
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 24),
          onPressed: onPressed,
          padding: const EdgeInsets.all(12),
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
          // Remote video (full screen)
          Positioned.fill(child: _buildRemoteVideo()),
          
          // Local preview (draggable)
          if (_isEngineInitialized && _remoteUid != null)
            Positioned(
              left: previewX,
              top: previewY,
              child: _buildLocalPreview(),
            ),
          
          // Top status bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      final shouldEnd = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text("End Consultation?", style: TextStyle(color: Colors.white)),
                          content: const Text("Are you sure you want to end this consultation?", style: TextStyle(color: Colors.white70)),
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
                        await _endConsultation();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Consultation",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isJoined ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isJoined ? "Connected" : "Connecting...",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
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
          
          // Control buttons (right side)
          Positioned(
            bottom: 120,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  onPressed: _toggleScreenShare,
                  backgroundColor: _isScreenSharing ? Colors.orange : Colors.blueGrey[800]!,
                  tooltip: _isScreenSharing ? "Stop sharing" : "Share screen",
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  onPressed: () async {
                    final shouldEnd = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text("End Consultation?", style: TextStyle(color: Colors.white)),
                        content: const Text("Are you sure you want to end this consultation?", style: TextStyle(color: Colors.white70)),
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
                      await _endConsultation();
                    }
                  },
                  backgroundColor: Colors.red,
                  tooltip: "End call",
                ),
              ],
            ),
          ),
          
          // Chat sheet (bottom)
          _buildChatSheet(),
        ],
      ),
    );
  }
}
