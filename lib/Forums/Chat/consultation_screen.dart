import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class ConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isInitiator;

  ConsultationScreen({
    required this.channelName,
    required this.isInitiator,
  });

  @override
  _ConsultationScreenState createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  static const String _appId = '5b4b59f66dbb474cbcf39dd3ac19905a';
  late final RtcEngine _engine;
  bool _isJoined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isEngineInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Check permissions
    var cameraStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;
    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      await [Permission.camera, Permission.microphone].request();
      cameraStatus = await Permission.camera.status;
      micStatus = await Permission.microphone.status;
      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Camera or microphone permission denied')),
        );
        return;
      }
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _isEngineInitialized = true;
      print('Agora initialized successfully');

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              _isJoined = true;
            });
            print('Joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUid = remoteUid;
            });
            print('User $remoteUid joined');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() {
              _remoteUid = null;
            });
            print('User $remoteUid offline: $reason');
            _endConsultation();
          },
          onError: (ErrorCodeType err, String msg) {
            print('Agora error: $err, $msg');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Agora error: $msg')),
            );
            if (err == ErrorCodeType.errInvalidToken) {
              _retryJoinChannel();
            }
          },
        ),
      );

      // Set video encoder configuration to avoid unrecognized profile warnings
      await _engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 360),
          frameRate: 15,
          bitrate: 400,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      await _engine.enableVideo();
      await _engine.muteLocalVideoStream(false);
      await _engine.muteLocalAudioStream(false);
      await _engine.startPreview();
      print('Video preview started');

      // For testing, use empty token; for production, fetch from server
      const String token = ''; // Replace with: await fetchAgoraToken(widget.channelName, FirebaseAuth.instance.currentUser!.uid);
      print('Joining channel: ${widget.channelName}, token: $token');
      await _engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
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

  Future<void> _retryJoinChannel() async {
    if (!_isEngineInitialized) return;
    try {
      print('Retrying channel join');
      await _engine.leaveChannel();
      const String token = ''; // Replace with: await fetchAgoraToken(widget.channelName, FirebaseAuth.instance.currentUser!.uid);
      await _engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      print('Retry failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $e')),
      );
    }
  }

  Future<void> _endConsultation() async {
    try {
      await FirebaseFirestore.instance
          .collection('Consultations')
          .doc(widget.channelName)
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
        title: const Text('Live Consultation'),
      ),
      body: Stack(
        children: [
          _isJoined && _remoteUid != null
              ? AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: null),
              connection: RtcConnection(channelId: widget.channelName),
              useAndroidSurfaceView: true, // Use SurfaceView for Android
            ),
          )
              : const Center(child: Text('Waiting for participant...')),
          if (_isJoined)
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                    useAndroidSurfaceView: true, // Use SurfaceView for Android
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
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await _engine.stopPreview();
                      await _engine.startPreview();
                      setState(() {});
                    },
                  ),
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