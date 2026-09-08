import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../classwork_mode.dart';
import 'classroom_models.dart';

class ClassworkSessionScreen extends StatefulWidget {
  final ClassroomAssignment assignment;
  const ClassworkSessionScreen({super.key, required this.assignment});

  @override
  State<ClassworkSessionScreen> createState() => _ClassworkSessionScreenState();
}

class _ClassworkSessionScreenState extends State<ClassworkSessionScreen> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _recording = false;
  bool _starting = false;
  DateTime? _startedAt;
  String? _error;
  final _supabase = Supabase.instance.client;
  final _answerController = TextEditingController();
  final _accent = const Color(0xFF32C5FF);

  @override
  void initState() {
    super.initState();
    _prepareCamera();
  }

  Future<void> _prepareCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() => _error = 'Camera permission is required for monitored classwork.');
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera available');
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final description = front.isNotEmpty ? front.first : cameras.first;
      final controller = CameraController(description, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start the camera.');
    }
  }

  Future<void> _startSession() async {
    if (_starting || _recording || !_cameraReady) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      setClassworkMode(true);
      final name = 'lodha_classwork_${widget.assignment.id}_${DateTime.now().millisecondsSinceEpoch}';
      final started = await FlutterScreenRecording.startRecordScreen(
        name,
        titleNotification: 'Lodha Inspiro classwork',
        messageNotification: 'Your whole screen is being recorded for this assignment.',
      );
      if (!started) {
        setClassworkMode(false);
        throw Exception('Screen recording permission was not granted');
      }
      if (!mounted) return;
      setState(() {
        _recording = true;
        _starting = false;
        _startedAt = DateTime.now();
      });
    } catch (_) {
      setClassworkMode(false);
      if (mounted) {
        setState(() {
          _starting = false;
          _error = 'Could not start monitored recording. Please try again.';
        });
      }
    }
  }

  Future<void> _stopSession() async {
    if (!_recording) return;
    if (_answerController.text.trim().isEmpty) {
      setState(() => _error = 'Please finish the written work before submitting.');
      return;
    }
    setState(() => _starting = true);
    try {
      final path = await FlutterScreenRecording.stopRecordScreen;
      final duration = _startedAt == null ? null : DateTime.now().difference(_startedAt!).inSeconds;
      await _uploadRecording(path, duration);
      await _supabase.from('classroom_submissions').upsert({
        'assignment_id': widget.assignment.id,
        'student_id': _supabase.auth.currentUser!.id,
        'text': _answerController.text.trim(),
      }, onConflict: 'assignment_id,student_id');
      setClassworkMode(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classwork recording submitted to your teacher.')));
        Navigator.pop(context);
      }
    } catch (_) {
      setClassworkMode(false);
      if (mounted) {
        setState(() {
          _starting = false;
          _error = 'The recording could not be submitted. Please try again.';
        });
      }
    }
  }

  Future<void> _uploadRecording(String localPath, int? duration) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final source = File(localPath);
    if (!await source.exists()) throw Exception('Recording file was not created');
    final storagePath = '${user.id}/${widget.assignment.id}/${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _supabase.storage.from('classroom-recordings').upload(
      storagePath,
      source,
      fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
    );
    await _supabase.from('classroom_recordings').insert({
      'assignment_id': widget.assignment.id,
      'student_id': user.id,
      'storage_path': storagePath,
      'duration_seconds': duration,
    });
    try {
      await source.delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _answerController.dispose();
    setClassworkMode(false);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return PopScope(
      canPop: !_recording && !_starting,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E1116) : const Color(0xFFEAF1F6),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Monitored classwork', style: TextStyle(color: text, fontWeight: FontWeight.bold)),
          iconTheme: IconThemeData(color: text),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            _glassCard(isDark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_recording ? Icons.fiber_manual_record_rounded : Icons.verified_user_rounded, color: _recording ? Colors.redAccent : _accent),
                const SizedBox(width: 10),
                Expanded(child: Text(_recording ? 'Recording active' : 'Teacher-supervised mode', style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 18))),
              ]),
              const SizedBox(height: 10),
              Text('The entire device screen is recorded while you work. Lodha Inspiro AI is unavailable until you submit the work. Your front camera preview is included in the screen recording.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.4)),
            ])),
            const SizedBox(height: 16),
            _glassCard(isDark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.assignment.title, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 21)),
              if (widget.assignment.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(widget.assignment.description!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.35)),
              ],
            ])),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              minLines: 6,
              maxLines: 12,
              enabled: !_recording,
              style: TextStyle(color: text, fontFamily: 'Google Sans Flex'),
              decoration: InputDecoration(
                labelText: 'Your work',
                hintText: 'Complete the assignment here while monitored.',
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _cameraReady && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : Container(color: isDark ? Colors.white10 : Colors.black12, alignment: Alignment.center, child: Text(_error ?? 'Preparing camera…', style: TextStyle(color: text))),
              ),
            ),
            const SizedBox(height: 8),
            Text('Camera preview. Audio is not recorded.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _starting || !_cameraReady ? null : (_recording ? _stopSession : _startSession),
                icon: Icon(_recording ? Icons.stop_rounded : Icons.screen_record_rounded),
                label: Text(_starting ? 'Please wait…' : (_recording ? 'Finish & submit recording' : 'Start monitored work')),
                style: ElevatedButton.styleFrom(backgroundColor: _recording ? Colors.redAccent : _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            ),
            const SizedBox(height: 10),
            Text('Screen capture uses Android MediaProjection, so Android will show a recording-consent prompt before the session begins.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _glassCard(bool isDark, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.78),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: isDark ? Colors.white12 : Colors.white, width: 1.2),
    ),
    child: child,
  );
}
