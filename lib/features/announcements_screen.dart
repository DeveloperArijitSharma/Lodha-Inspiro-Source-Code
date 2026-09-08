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
      // The screen remains usable even before an announcements table is configured.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * .25), Icon(Icons.campaign_outlined, size: 64, color: dark ? Colors.white30 : Colors.black26), const SizedBox(height: 16), Center(child: Text('No announcements yet.', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex')))])
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final a = _items[i];
                      return Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: dark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['title']?.toString() ?? 'Announcement', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), const SizedBox(height: 8), Text(a['body']?.toString() ?? a['message']?.toString() ?? '', style: TextStyle(color: dark ? Colors.white70 : Colors.black87, height: 1.4, fontFamily: 'Google Sans Flex'))]));
                    },
                  ),
      ),
    );
  }
}
