import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_preferences.dart';
import 'chat_screen.dart';
import 'classroom/classroom_screen.dart';
import 'classroom/teacher_recordings_screen.dart';
import 'file_manager/file_manager_screen.dart';
import 'notebooks/notebooks_list_screen.dart';
import 'widgets/advanced_settings_section.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});
  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  final _supabase = Supabase.instance.client;
  int _index = 0;
  int _chatFilter = 0;
  List<Map<String, dynamic>> _chats = [];
  bool _chatLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final rows = await _supabase.from('chats').select().order('created_at', ascending: false);
      if (mounted) setState(() { _chats = List<Map<String, dynamic>>.from(rows); _chatLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  void _setIndex(int value) {
    if (hapticsNotifier.value) HapticFeedback.selectionClick();
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      drawer: _buildDrawer(dark),
      backgroundColor: dark ? const Color(0xFF070B12) : const Color(0xFFF1F5FA),
      body: Stack(children: [
        const _ShellBackground(),
        SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 420), switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic, child: KeyedSubtree(key: ValueKey(_index), child: _page()))),
      ]),
      bottomNavigationBar: _GlassNavigation(index: _index, dark: dark, onSelect: _setIndex),
    );
  }

  Widget _page() {
    switch (_index) {
      case 0: return const NotebooksListScreen();
      case 1: return const ClassroomScreen();
      case 2: return const FileManagerScreen();
      case 3: return _chatPage();
      default: return const NotebooksListScreen();
    }
  }

  Widget _chatPage() {
    final type = _chatFilter == 0 ? 'classmate' : _chatFilter == 1 ? 'teacher' : 'group';
    final chats = _chats.where((chat) => chat['chat_type'] == type).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 10), child: _PageHeader(title: 'Messages', icon: CupertinoIcons.chat_bubble_2, onMenu: () => Scaffold.of(context).openDrawer())),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _ChatFilters(selected: _chatFilter, onSelect: (v) => setState(() => _chatFilter = v))),
      const SizedBox(height: 12),
      Expanded(child: _chatLoading ? const Center(child: CupertinoActivityIndicator(radius: 14)) : chats.isEmpty ? const Center(child: Text('No conversations here yet.', style: TextStyle(fontWeight: FontWeight.w600))) : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 0, 18, 130), itemCount: chats.length, itemBuilder: (_, i) { final chat = chats[i]; return _ChatCard(chat: chat, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat['id'], chatName: chat['chat_name'], chatType: chat['chat_type']))); })));
    ]);
  }

  Widget _buildDrawer(bool dark) {
    final user = _supabase.auth.currentUser;
    final name = user?.userMetadata?['username']?.toString() ?? 'Student Portal';
    final email = user?.email ?? '';
    return Drawer(backgroundColor: Colors.transparent, child: ClipRRect(borderRadius: const BorderRadius.horizontal(right: Radius.circular(38)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(decoration: BoxDecoration(color: dark ? Colors.black.withOpacity(.58) : Colors.white.withOpacity(.70), border: Border(right: BorderSide(color: dark ? Colors.white12 : Colors.white))), child: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4B8DFF).withOpacity(.18)), child: const Icon(CupertinoIcons.person_fill, color: Color(0xFF4B8DFF))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontSize: 12))]))]),
      const SizedBox(height: 24),
      _DrawerButton(icon: CupertinoIcons.home, title: 'Home', onTap: () { Navigator.pop(context); _setIndex(0); }),
      _DrawerButton(icon: CupertinoIcons.folder, title: 'File Manager', onTap: () { Navigator.pop(context); _setIndex(2); }),
      _DrawerButton(icon: CupertinoIcons.bell, title: 'Announcements', onTap: () => Navigator.pop(context)),
      _DrawerButton(icon: CupertinoIcons.settings, title: 'Settings', onTap: () { Navigator.pop(context); _showSettings(dark); }),
      if (user?.userMetadata?['role']?.toString() == 'teacher') _DrawerButton(icon: CupertinoIcons.video_camera, title: 'Student recordings', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRecordingsScreen())); }),
      const Spacer(),
      _DrawerButton(icon: CupertinoIcons.square_arrow_right, title: 'Sign out', destructive: true, onTap: () async { await _supabase.auth.signOut(); }),
    ]))))));
  }

  Future<void> _showSettings(bool dark) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => Container(height: MediaQuery.of(context).size.height * .82, decoration: BoxDecoration(color: dark ? const Color(0xFF111722).withOpacity(.96) : Colors.white.withOpacity(.96), borderRadius: const BorderRadius.vertical(top: Radius.circular(34))), child: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [Text('Settings', style: TextStyle(color: dark ? Colors.white : const Color(0xFF172033), fontSize: 28, fontWeight: FontWeight.w800)), const SizedBox(height: 20), AdvancedSettingsSection(isDark: dark, accentColor: const Color(0xFF4B8DFF))]))));
  }
}

class _ShellBackground extends StatelessWidget {
  const _ShellBackground();
  @override
  Widget build(BuildContext context) => Stack(children: [Positioned(top: -140, right: -100, child: _orb(330, const Color(0xFF4B8DFF))), Positioned(top: 250, left: -170, child: _orb(340, const Color(0xFF9A7BFF))), Positioned(bottom: -180, right: -120, child: _orb(380, const Color(0xFF54D6BE))), Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container(color: Colors.transparent)))]);
  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.14), boxShadow: [BoxShadow(color: color.withOpacity(.18), blurRadius: 90, spreadRadius: 25)]));
}

class _GlassNavigation extends StatelessWidget {
  final int index;
  final bool dark;
  final ValueChanged<int> onSelect;
  const _GlassNavigation({required this.index, required this.dark, required this.onSelect});
  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: ClipRRect(borderRadius: BorderRadius.circular(34), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.09) : Colors.white.withOpacity(.68), borderRadius: BorderRadius.circular(34), border: Border.all(color: dark ? Colors.white.withOpacity(.13) : Colors.white, width: 1.2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 28, offset: const Offset(0, 10))]), child: Row(children: [
    _NavItem(index: 0, current: index, icon: CupertinoIcons.house_fill, label: 'Home', onSelect: onSelect),
    _NavItem(index: 1, current: index, icon: CupertinoIcons.book, label: 'Classwork', onSelect: onSelect),
    _NavItem(index: 2, current: index, icon: CupertinoIcons.folder_fill, label: 'Files', onSelect: onSelect),
    _NavItem(index: 3, current: index, icon: CupertinoIcons.chat_bubble_2_fill, label: 'Chat', onSelect: onSelect),
  ])))));
}

class _NavItem extends StatelessWidget {
  final int index;
  final int current;
  final IconData icon;
  final String label;
  final ValueChanged<int> onSelect;
  const _NavItem({required this.index, required this.current, required this.icon, required this.label, required this.onSelect});
  @override
  Widget build(BuildContext context) { final selected = current == index; return Expanded(child: GestureDetector(onTap: () => onSelect(index), child: AnimatedContainer(duration: const Duration(milliseconds: 360), curve: Curves.easeOutBack, padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: selected ? const Color(0xFF4B8DFF).withOpacity(.16) : Colors.transparent, borderRadius: BorderRadius.circular(27)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: selected ? const Color(0xFF4B8DFF) : Theme.of(context).iconTheme.color?.withOpacity(.62), size: 21), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? const Color(0xFF4B8DFF) : null))])))); }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onMenu;
  const _PageHeader({required this.title, required this.icon, required this.onMenu});
  @override
  Widget build(BuildContext context) => Row(children: [IconButton(onPressed: onMenu, icon: const Icon(CupertinoIcons.line_horizontal_3)), const SizedBox(width: 4), Icon(icon, color: const Color(0xFF4B8DFF)), const SizedBox(width: 9), Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))]);
}

class _ChatFilters extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _ChatFilters({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Row(children: ['Classmates', 'Teachers', 'Groups'].asMap().entries.map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: GestureDetector(onTap: () => onSelect(e.key), child: AnimatedContainer(duration: const Duration(milliseconds: 260), padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: selected == e.key ? const Color(0xFF4B8DFF).withOpacity(.15) : Colors.white.withOpacity(.42), borderRadius: BorderRadius.circular(20)), child: Center(child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: selected == e.key ? FontWeight.w800 : FontWeight.w600)))))))).toList());
}

class _ChatCard extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  const _ChatCard({required this.chat, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ClipRRect(borderRadius: BorderRadius.circular(23), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Material(color: Colors.white.withOpacity(.62), child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4B8DFF).withOpacity(.14)), child: const Icon(CupertinoIcons.person_2_fill, color: Color(0xFF4B8DFF))), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${chat['chat_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 4), const Text('Open conversation', style: TextStyle(color: Colors.black45, fontSize: 12))])), const Icon(CupertinoIcons.chevron_right, color: Color(0xFF4B8DFF), size: 18)]))))));
}

class _DrawerButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;
  const _DrawerButton({required this.icon, required this.title, required this.onTap, this.destructive = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: ListTile(leading: Icon(icon, color: destructive ? Colors.redAccent : const Color(0xFF4B8DFF)), title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: destructive ? Colors.redAccent : null)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), onTap: onTap));
}
