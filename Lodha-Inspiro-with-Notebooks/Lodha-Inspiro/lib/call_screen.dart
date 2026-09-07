import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String callID;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.callID,
    required this.isVideoCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // 1. Request microphone and camera permissions
    await [Permission.microphone, Permission.camera].request();

    // 2. Create and initialize the Agora RTC Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId:
          "9d44804db89440c497054a8ca1977a62", // 🔴 Paste your Agora App ID here
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. Register event handlers to track users joining/leaving
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
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    // 4. Enable video if it's a video call, otherwise disable it for voice-only
    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    // 5. Join the channel using your Token and Room ID
    await _engine.joinChannel(
      token:
          "007eJxTYHi5Rsb2VQ+r4nvD49bG1X/PHV7y5bBRaN9DOw+pno7TC5kVGCxTTEwsDExSkiwsTUwMkk0szQ1MTRItkhMNLc3NE82Mlj3MzGoIZGTgnMjOxMgAgWA+Q0lqcUl8cmJODgMDAAuRIRQ=", // 🔴 Paste your Agora Temp Token here
      channelId: widget.callID,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Stack(
          children: [
            // Remote User Video or Waiting Screen
            Center(
              child: _remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(channelId: widget.callID),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Color(0xFF32C5FF)),
                        const SizedBox(height: 16),
                        Text(
                          'Calling ${widget.callID}...\nWaiting for other user to join',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontFamily: 'Google Sans Flex'),
                        ),
                      ],
                    ),
            ),

            // Local User Video (Floating in top right corner during video calls)
            if (widget.isVideoCall && _localUserJoined)
              Positioned(
                top: 20,
                right: 20,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24, width: 1.5)),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),

            // Top Bar with Back Button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Bottom Control Bar (End Call Button)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    backgroundColor: Colors.redAccent,
                    elevation: 5,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 28),
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
