import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isInitiator;
  final String chatId;
  final String initiatorId; // added to fetch user info

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
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;

  final TextEditingController _commentController = TextEditingController();
  final List<String> _comments = [];
  bool _showEmojiPicker = false;

  int _likes = 0;
  int _viewerCount = 1;

  String initiatorName = "";
  String initiatorPic = "";

  @override
  void initState() {
    super.initState();
    _initSetup();
    _loadInitiatorDetails();
  }

  Future<void> _loadInitiatorDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget.initiatorId)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          initiatorName =
              "${data['Fname'] ?? ''} ${data['Lname'] ?? ''}".trim();
          initiatorPic = data['User Pic'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error loading initiator: $e");
    }
  }

  Future<void> _initSetup() async {
    await _initAgora();
    await _handlePermissions();
  }

  Future<void> _handlePermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: "873c3e4a81ca45cb92806d6362381790",
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
            _viewerCount++;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          setState(() {
            _remoteUid = null;
            _viewerCount = (_viewerCount > 1) ? _viewerCount - 1 : 1;
          });
        },
      ),
    );

    await _engine.enableVideo();

    await _engine.setClientRole(
      role: widget.isInitiator
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    await _engine.joinChannel(
      token: "",
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _endStreamCleanup() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId);

      if (widget.isInitiator) {
        await docRef.update({
          'status': 'ended',
          'viewerCount': _viewerCount,
        });
      } else {
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          final currentCount = snapshot['viewerCount'] ?? 0;
          await docRef.update({
            'viewerCount': (currentCount > 0) ? currentCount - 1 : 0,
          });
        }
      }

      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("⚠️ Error during cleanup: $e");
    }
  }

  @override
  void dispose() {
    _endStreamCleanup();
    _commentController.dispose();
    super.dispose();
  }

  Widget _renderVideo() {
    if (widget.isInitiator) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      if (_remoteUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return const Center(
          child: Text(
            "Waiting for host...",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        );
      }
    }
  }

  Widget _buildCommentsOverlay() {
    return Positioned(
      left: 10,
      bottom: 90,
      right: 10,
      child: SizedBox(
        height: 180,
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: _comments.length,
          itemBuilder: (context, index) {
            final text = _comments[index];
            final clipped =
            text.length > 50 ? "${text.substring(0, 50)}..." : text;

            return TweenAnimationBuilder<double>(
              key: ValueKey(_comments[index]),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.black.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined,
                      color: Colors.white70),
                  onPressed: () {
                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white70),
                  onPressed: () {
                    if (_commentController.text.trim().isNotEmpty) {
                      setState(() {
                        _comments.insert(0, _commentController.text.trim());
                        _commentController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          _showEmojiPicker
              ? SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _commentController.text += emoji.emoji;
              },
            ),
          )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildOverlayButtons() {
    return Positioned(
      top: 20,
      right: 16,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye,
                    color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_viewerCount',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          FloatingActionButton(
            heroTag: "likeBtn",
            backgroundColor: Colors.grey.shade800,
            mini: true,
            onPressed: () => setState(() => _likes++),
            child: const Icon(Icons.favorite, color: Colors.red),
          ),
          const SizedBox(height: 5),
          Text('$_likes',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),

          const SizedBox(height: 15),
          if (widget.isInitiator && _localUserJoined)
            FloatingActionButton(
              heroTag: "cameraSwitchBtn",
              backgroundColor: Colors.grey.shade700,
              onPressed: () async {
                await _engine.switchCamera();
              },
              child: const Icon(Icons.cameraswitch, color: Colors.white),
            ),
          const SizedBox(height: 15),
          if (widget.isInitiator)
            FloatingActionButton(
              heroTag: "endStreamBtn",
              backgroundColor: Colors.red.shade700,
              onPressed: () async {
                await _endStreamCleanup();
                if (mounted) Navigator.pop(context);
              },
              child: const Icon(Icons.call_end, color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: initiatorPic.isNotEmpty
                  ? NetworkImage(initiatorPic)
                  : const AssetImage("assets/Images/placeholder.png")
              as ImageProvider,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                initiatorName.isNotEmpty ? initiatorName : "Loading...",
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "LIVE",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _renderVideo()),
          _buildCommentsOverlay(),
          _buildOverlayButtons(),
          _buildCommentInput(),
        ],
      ),
    );
  }
}
