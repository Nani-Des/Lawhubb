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
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera & microphone permissions required")),
        );
      }
      setState(() => _loading = false);
      return;
    }

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: _appId));
      _engine = engine;
      _isEngineInitialized = true;

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() => _isJoined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() => _remoteUid = null);
          },
        ),
      );

      await engine.enableVideo();
      await engine.startPreview();

      await engine.joinChannel(
        token: "",
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      print("⚠️ Agora init error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start consultation: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleScreenShare() async {
    if (!_isEngineInitialized || _engine == null) return;
    try {
      if (_isScreenSharing) {
        await _engine!.stopScreenCapture();
        setState(() => _isScreenSharing = false);
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
        setState(() => _isScreenSharing = true);
      }
    } catch (e) {
      print("⚠️ Screen share error: $e");
    }
  }

  Future<void> _endConsultation() async {
    try {
      await FirebaseFirestore.instance
          .collection("Consultations")
          .doc(widget.channelName)
          .update({
        "status": "ended",
        "endTimestamp": FieldValue.serverTimestamp(),
      });

      await _engine?.stopPreview();
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _endConsultation();
    super.dispose();
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
    return const Center(
      child: Text("Waiting for participant...", style: TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildDraggablePreview() {
    return Positioned(
      left: previewX,
      top: previewY,
      child: Draggable(
        feedback: _localPreviewBox(),
        childWhenDragging: const SizedBox(),
        onDragEnd: (details) {
          setState(() {
            previewX = details.offset.dx;
            previewY = details.offset.dy;
          });
        },
        child: _localPreviewBox(),
      ),
    );
  }

  Widget _localPreviewBox() {
    return Container(
      width: 130,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildChatSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("Consultations")
                      .doc(widget.channelName)
                      .collection("messages")
                      .orderBy("timestamp", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final messages = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      controller: scrollController,
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        final isMe = msg["senderId"] == userId;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blueGrey[800] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg["text"],
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.grey[800],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.blueGrey[700],
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () async {
                          if (_chatController.text.trim().isEmpty) return;
                          await FirebaseFirestore.instance
                              .collection("Consultations")
                              .doc(widget.channelName)
                              .collection("messages")
                              .add({
                            "senderId": userId,
                            "text": _chatController.text.trim(),
                            "timestamp": FieldValue.serverTimestamp(),
                          });
                          _chatController.clear();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildRemoteVideo()),
          if (_isEngineInitialized) _buildDraggablePreview(),
          _buildChatSheet(),
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "share",
                  backgroundColor: Colors.blueGrey[800],
                  onPressed: _toggleScreenShare,
                  child: Icon(
                    _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "end",
                  backgroundColor: Colors.redAccent,
                  onPressed: _endConsultation,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
