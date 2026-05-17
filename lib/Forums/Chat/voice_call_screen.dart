import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Services/config_service.dart';
import '../../widgets/profile_avatar.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String recipientId;
  final String recipientName;
  final bool isInitiator;

  const VoiceCallScreen({
    required this.channelName,
    required this.recipientId,
    required this.recipientName,
    required this.isInitiator,
    Key? key,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final ConfigService _configService = ConfigService();
  RtcEngine? _engine;

  bool _isJoined = false;
  int? _remoteUid;
  bool _isEngineInitialized = false;
  bool _loading = true;
  bool _isMuted = false;
  bool _isDisposing = false;
  Timer? _callTimer;
  int _callDuration = 0;
  String? _recipientPic;

  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    if (userId == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.recipientId)
          .get();
      if (mounted) {
        setState(() {
          _recipientPic = userDoc.data()?['User Pic'] as String?;
        });
      }

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Microphone permission required"),
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
            setState(() {
              _isJoined = true;
              _loading = false;
            });
            _startCallTimer();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (!mounted || _isDisposing) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (!mounted || _isDisposing) return;
            setState(() => _remoteUid = null);
            _endCall();
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

      // Enable audio only (no video)
      await engine.enableAudio();
      await engine.disableVideo();

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

      // Update Firestore call status
      await FirebaseFirestore.instance
          .collection("VoiceCalls")
          .doc(widget.channelName)
          .set({
        "callId": widget.channelName,
        "callerId": userId,
        "recipientId": widget.recipientId,
        "status": "active",
        "startTimestamp": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ Agora init error: $e");
      if (mounted && !_isDisposing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to start call: $e"),
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

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isDisposing) {
        setState(() {
          _callDuration++;
        });
      }
    });
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

  Future<void> _endCall() async {
    if (_isDisposing) return;
    _isDisposing = true;

    _callTimer?.cancel();

    try {
      // Update Firestore call status
      await FirebaseFirestore.instance
          .collection("VoiceCalls")
          .doc(widget.channelName)
          .update({
        "status": "ended",
        "endTimestamp": FieldValue.serverTimestamp(),
        "duration": _callDuration,
      }).catchError((e) => debugPrint("Firestore update error: $e"));
    } catch (e) {
      debugPrint("Error updating call status: $e");
    }

    try {
      // Cleanup Agora engine
      if (_engine != null) {
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                _isJoined ? "Connecting..." : "Calling ${widget.recipientName}...",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      final shouldEnd = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text("End Call?", style: TextStyle(color: Colors.white)),
                          content: const Text("Are you sure you want to end this call?", style: TextStyle(color: Colors.white70)),
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
                        await _endCall();
                      }
                    },
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            // Profile section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isJoined && _remoteUid != null
                            ? Colors.green
                            : Colors.grey[700]!,
                        width: 3,
                      ),
                    ),
                    child: ProfileAvatar.circle(
                      imageUrl: _recipientPic,
                      radius: 72,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Name
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isJoined && _remoteUid != null
                              ? Colors.green
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isJoined && _remoteUid != null
                            ? "Connected"
                            : _isJoined
                                ? "Waiting for answer..."
                                : "Connecting...",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Control buttons
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute button
                  Container(
                    decoration: BoxDecoration(
                      color: _isMuted ? Colors.red : Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _toggleMute,
                      padding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // End call button
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _endCall,
                      padding: const EdgeInsets.all(20),
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
}

