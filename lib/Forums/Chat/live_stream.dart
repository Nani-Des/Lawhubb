import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isInitiator;
  final String chatId;

  const LiveConsultationScreen({
    required this.channelName,
    required this.isInitiator,
    required this.chatId,
    Key? key,
  }) : super(key: key);

  @override
  _LiveConsultationScreenState createState() => _LiveConsultationScreenState();
}

class _LiveConsultationScreenState extends State<LiveConsultationScreen> {
  static const String _appId = '3f94329a35ed47a49fe46f463542d097'; // Your Agora App ID
  late final RtcEngine _engine;
  bool _isJoined = false;
  List<int> _remoteUids = [];
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isEngineInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request permissions for initiator and recipients (all need camera/mic for flexibility)
    var status = await [Permission.camera, Permission.microphone].request();
    if (!status[Permission.camera]!.isGranted || !status[Permission.microphone]!.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera or microphone permission denied')),
      );
      return;
    }

    try {
      // Initialize Agora engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      _isEngineInitialized = true;
      print('Agora engine initialized');

      // Register event handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              _isJoined = true;
            });
            print('Joined channel: ${connection.channelId}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Joined consultation')),
            );
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUids.add(remoteUid);
            });
            print('User $remoteUid joined');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() {
              _remoteUids.remove(remoteUid);
            });
            print('User $remoteUid offline: $reason');
            if (_remoteUids.isEmpty && widget.isInitiator) {
              _endConsultation();
            }
          },
          onError: (ErrorCodeType err, String msg) {
            print('Agora error: $err, $msg');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Agora error: $msg')),
            );
          },
        ),
      );

      // Configure video for initiator
      if (widget.isInitiator) {
        await _engine.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 360),
            frameRate: 15,
            bitrate: 400,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
        await _engine.enableVideo();
        await _engine.startPreview();
        print('Video preview started');
      }

      // Set client role and join channel
      await _engine.setClientRole(
        role: widget.isInitiator
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience, // Recipients as audience by default
      );
      await _engine.joinChannel(
        token: '', // Empty for testing (token authentication disabled)
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      print('Agora initialization failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize Agora: $e')),
      );
    }
  }

  Future<void> _endConsultation() async {
    if (!_isEngineInitialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.chatId)
          .update({
        'status': 'ended',
        'endTimestamp': FieldValue.serverTimestamp(),
      });
      await _engine.stopPreview();
      await _engine.leaveChannel();
      print('Left channel');
    } catch (e) {
      print('Error ending consultation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end consultation: $e')),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    if (_isEngineInitialized) {
      _engine.stopPreview();
      _engine.leaveChannel();
      _engine.release();
      print('Agora engine released');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitiator ? 'Host Consultation' : 'Join Consultation'),
      ),
      body: Stack(
        children: [
          _isJoined && _remoteUids.isNotEmpty
              ? AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _remoteUids.first),
              connection: RtcConnection(channelId: widget.channelName),
              useAndroidSurfaceView: true,
            ),
          )
              : const Center(child: Text('Waiting for participants...')),
          if (widget.isInitiator && _isJoined)
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                    useAndroidSurfaceView: true,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isInitiator) ...[
                    IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        _engine.muteLocalAudioStream(_isMuted);
                      },
                    ),
                    IconButton(
                      icon: Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                      onPressed: () {
                        setState(() {
                          _isVideoEnabled = !_isVideoEnabled;
                        });
                        _engine.muteLocalVideoStream(!_isVideoEnabled);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.switch_camera),
                      onPressed: () {
                        _engine.switchCamera();
                      },
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.red),
                    onPressed: _endConsultation,
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