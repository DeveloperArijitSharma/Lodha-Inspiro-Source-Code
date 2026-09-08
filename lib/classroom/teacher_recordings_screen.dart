import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherRecordingsScreen extends StatefulWidget {
  const TeacherRecordingsScreen({super.key});

  @override
  State<TeacherRecordingsScreen> createState() => _TeacherRecordingsScreenState();
}

class _TeacherRecordingsScreenState extends State<TeacherRecordingsScreen> {
  final _supabase = Supabase.instance.client;
  final _channel = const MethodChannel('lodha_inspiro/native');
  final _accent = const Color(0xFF32C5FF);
  bool _loading = true;
  List<Map<String, dynamic>> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    try {
      final role = _supabase.auth.currentUser?.userMetadata?['role']?.toString();
      if (role != 'teacher') throw Exception('Teacher access required');
      final rows = await _supabase
          .from('classroom_recordings')
          .select('id, assignment_id, student_id, storage_path, duration_seconds, created_at, classroom_assignments(title)')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _recordings = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _recordings = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> recording) async {
    try {
      final path = recording['storage_path'] as String;
      final bytes = await _supabase.storage.from('classroom-recordings').download(path);
      final filename = 'classwork_${recording['assignment_id']}_${recording['created_at'].toString().replaceAll(':', '-')}.mp4';
      await _channel.invokeMethod('saveToDownloads', {
        'filename': filename,
        'mimeType': 'video/mp4',
        'bytes': Uint8List.fromList(bytes),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording saved to Downloads.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download recording.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101318) : const Color(0xFFEAF1F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Student recordings', style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: text),
      ),
      body: RefreshIndicator(
        color: _accent,
        onRefresh: _loadRecordings,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  _infoCard(isDark, text),
                  const SizedBox(height: 18),
                  if (_recordings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: Text('No submitted recordings yet.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
                    )
                  else
                    ..._recordings.map((recording) => _recordingCard(recording, isDark, text)),
                ],
              ),
      ),
    );
  }

  Widget _infoCard(bool isDark, Color text) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: isDark ? Colors.white12 : Colors.white),
    ),
    child: Row(children: [
      Icon(Icons.lock_rounded, color: _accent),
      const SizedBox(width: 12),
      Expanded(child: Text('Only teacher accounts can download monitored classwork recordings.', style: TextStyle(color: text, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _recordingCard(Map<String, dynamic> recording, bool isDark, Color text) {
    final assignment = recording['classroom_assignments'];
    final title = assignment is Map<String, dynamic> ? assignment['title']?.toString() ?? 'Classwork' : 'Classwork';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.06) : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _accent.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.videocam_rounded, color: _accent)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: text, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Student: ${recording['student_id']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
        ])),
        IconButton(onPressed: () => _download(recording), icon: Icon(Icons.download_rounded, color: _accent), tooltip: 'Download'),
      ]),
    );
  }
}
