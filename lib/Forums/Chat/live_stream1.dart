import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Services/config_service.dart';

class LiveConsultationScreen1 extends StatefulWidget {
  final String channelName;
  final String chatId;
  final bool isInitiator;

  const LiveConsultationScreen1({
    Key? key,
    required this.channelName,
    required this.chatId,
    required this.isInitiator,
  }) : super(key: key);

  @override
  State<LiveConsultationScreen1> createState() => _LiveConsultationScreen1State();
}

class _LiveConsultationScreen1State extends State<LiveConsultationScreen1> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request mic/camera permissions
    await [Permission.microphone, Permission.camera].request();

    final configService = ConfigService();
    final appId = configService.agoraAppId;
    if (appId.isEmpty) {
      throw Exception('Agora App ID is not configured');
    }
    
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _joined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.enableVideo();

    await _engine.startPreview();

    await _engine.joinChannel(
      token: "YOUR_AGORA_TOKEN", // use token if security required, else null
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

  Widget _renderLocalPreview() {
    if (_joined) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      return const Center(child: Text("Joining consultation..."));
    }
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return const Center(child: Text("Waiting for participant..."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitiator ? "Hosting Consultation" : "Joining Consultation"),
      ),
      body: Stack(
        children: [
          Center(child: _renderRemoteVideo()),
          Positioned(
            right: 10,
            top: 10,
            width: 120,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _renderLocalPreview(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.call_end),
      ),
    );
  }
}
