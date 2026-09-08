import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rows = await _client.from('announcements').select().order('created_at', ascending: false);
      if (mounted) setState(() => _items = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0C1726) : const Color(0xFFF3F8FF),
      appBar: AppBar(title: const Text('Announcements', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                itemCount: _items.isEmpty ? 1 : _items.length,
                itemBuilder: (_, i) {
                  if (_items.isEmpty) return SizedBox(height: 420, child: Center(child: Text('No announcements yet.', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex'))));
                  final a = _items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: dark ? [const Color(0xFF173B59).withOpacity(.5), const Color(0xFF2D2550).withOpacity(.5)] : [Colors.white.withOpacity(.72), const Color(0xFFE8F7FF).withOpacity(.68)]),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.white.withOpacity(dark ? .14 : .75)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [const Icon(Icons.campaign_rounded, color: Color(0xFF32C5FF)), const SizedBox(width: 10), Expanded(child: Text(a['title']?.toString() ?? 'Announcement', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')))]),
                            const SizedBox(height: 10),
                            Text(a['body']?.toString() ?? a['message']?.toString() ?? '', style: TextStyle(color: dark ? Colors.white70 : Colors.black87, height: 1.45, fontFamily: 'Google Sans Flex')),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
