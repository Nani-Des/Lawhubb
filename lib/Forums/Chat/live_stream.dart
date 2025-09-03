import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class LiveConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isInitiator;
  final String chatId;

  const LiveConsultationScreen({
    Key? key,
    required this.channelName,
    required this.isInitiator,
    required this.chatId,
  }) : super(key: key);

  @override
  _LiveConsultationScreenState createState() => _LiveConsultationScreenState();
}

class _LiveConsultationScreenState extends State<LiveConsultationScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: "3a64afcc072c447fb9dd656ce980ecfb", // <-- replace with your Agora App ID
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("✅ Local user joined channel: ${connection.channelId}, uid: ${connection.localUid}");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("✅ Remote user joined: $remoteUid");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print("⚠️ Remote user left: $remoteUid, reason: $reason");
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    await _engine.enableVideo();

    // Set broadcaster vs audience role
    await _engine.setClientRole(
      role: widget.isInitiator
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    // Join the channel
    await _engine.joinChannel(
      token: "", // <-- leave empty if App Certificate is disabled
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Widget _renderVideo() {
    if (widget.isInitiator) {
      // Doctor / host view
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      // Audience view
      if (_remoteUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return const Center(child: Text("Waiting for host..."));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Consultation")),
      body: Center(child: _renderVideo()),
      floatingActionButton: widget.isInitiator && _localUserJoined
          ? FloatingActionButton(
        onPressed: () async {
          await _engine.switchCamera();
        },
        child: const Icon(Icons.cameraswitch),
      )
          : null,
    );
  }
}
