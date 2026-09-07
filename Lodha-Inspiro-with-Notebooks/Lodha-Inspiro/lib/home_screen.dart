import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'main.dart';
import 'notebooks/notebooks_list_screen.dart';
import 'ai/inspiro_ai_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  int _currentIndex = 0;
  String _userName = 'Student Portal';
  String _userEmail = '';

  final Color _accentBlue = const Color(0xFF32C5FF);

  int _selectedChatTab = 0;
  final List<Map<String, dynamic>> _chats = []; // Holds all chats from Supabase
  bool _isLoadingChats = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchChatsFromSupabase();
  }

  void _loadUser() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? 'student@lws.edu';
        _userName = user.userMetadata?['username'] ?? 'Student Portal';
      });
    }
  }

  // 🚀 FETCH PERMANENT CHATS FROM SUPABASE
  Future<void> _fetchChatsFromSupabase() async {
    try {
      final response = await supabase
          .from('chats')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _chats.clear();
        _chats.addAll(List<Map<String, dynamic>>.from(response));
        _isLoadingChats = false;
      });
    } catch (e) {
      setState(() => _isLoadingChats = false);
    }
  }

  // 🚀 DELETE CHAT PERMANENTLY
  Future<void> _deleteChat(String chatId, String chatName) async {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Chat?',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: Text('Delete conversation with $chatName?',
            style: const TextStyle(fontFamily: 'Google Sans Flex')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await supabase.from('chats').delete().eq('id', chatId);
              _fetchChatsFromSupabase();
              _showGlassSnackBar('Chat deleted permanently.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showGlassSnackBar(String message, {bool isError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.redAccent.withOpacity(isDark ? 0.4 : 0.6)
                    : _accentBlue.withOpacity(isDark ? 0.3 : 0.6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Google Sans Flex')),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    HapticFeedback.mediumImpact();
    await supabase.auth.signOut();
    if (mounted)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const AuthGate()));
  }

  Future<void> _updateUserName(String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      await supabase.auth
          .updateUser(UserAttributes(data: {'username': newName.trim()}));
      setState(() => _userName = newName.trim());
      _showGlassSnackBar('Display name updated successfully! ✨');
    } catch (e) {
      _showGlassSnackBar('Failed to update name.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double padding = size.width * 0.05;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _buildGlassDrawer(size, isDark),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentView(size, padding, isDark,
                    key: ValueKey<int>(_currentIndex)),
              ),
            ),
            Positioned(
              left: size.width * 0.04,
              right: size.width * 0.04,
              bottom: size.height * 0.02,
              child: _buildLiquidGlassNavBar(size, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(Size size, double padding, bool isDark,
      {required Key key}) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreenContent(size, padding, isDark);
      case 1:
        return _buildClassworkScreenContent(size, padding, isDark);
      case 2:
        return _buildChatTabContent(size, padding, isDark);
      case 3:
        return _buildSettingsScreenContent(size, padding, isDark);
      default:
        return _buildHomeScreenContent(size, padding, isDark);
    }
  }

  Widget _buildHeader(String title, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Builder(
          builder: (context) => IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.menu_rounded, color: textColor, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        const SizedBox(width: 14),
        Text(title,
            style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Google Sans Flex')),
      ],
    );
  }

  Widget _buildHomeScreenContent(Size size, double padding, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: EdgeInsets.fromLTRB(
          padding, size.height * 0.02, padding, size.height * 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Live classes', textColor),
          SizedBox(height: size.height * 0.018),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InspiroAiScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202A2F) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _accentBlue.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: _accentBlue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inspiro AI', style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Google Sans Flex',
                        )),
                        const SizedBox(height: 3),
                        Text('Ask, learn, plan and explore with your AI study assistant.',
                          style: TextStyle(
                            color: textColor.withOpacity(0.62),
                            fontSize: 13,
                            fontFamily: 'Google Sans Flex',
                          )),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 17, color: _accentBlue),
                ],
              ),
            ),
          ),
          SizedBox(height: size.height * 0.025),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(size.width * 0.06),
            decoration: BoxDecoration(
                color: const Color(0xFFD3B4FF),
                borderRadius: BorderRadius.circular(size.width * 0.08)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start',
                    style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Google Sans Flex')),
                SizedBox(height: size.height * 0.015),
                Text(
                    'Find the right level\nand book your first\nfree group class',
                    style: TextStyle(
                        color: const Color(0xFF1E1E1E),
                        fontSize: size.width * 0.055,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        fontFamily: 'Google Sans Flex')),
                SizedBox(height: size.height * 0.025),
                ElevatedButton(
                  onPressed: () =>
                      _showGlassSnackBar('Level Finder coming soon! 🚀'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E1E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24))),
                  child: const Text('Find level',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Google Sans Flex')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassworkScreenContent(Size size, double padding, bool isDark) {
    // 🚀 Notebooks: Gemini-grounded study notebooks (NotebookLM-style).
    // Lives inside the bottom-nav bounds, padded so it clears the floating
    // liquid glass nav bar at the bottom.
    return Padding(
      key: const ValueKey(1),
      padding: EdgeInsets.only(bottom: size.height * 0.11),
      child: const NotebooksListScreen(),
    );
  }

  Widget _buildTaskCard(
      String title, String subtitle, Color badgeColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Google Sans Flex')),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                      fontFamily: 'Google Sans Flex')),
            ],
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: badgeColor, size: 18),
        ],
      ),
    );
  }

  Widget _buildChatTabContent(Size size, double padding, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    // Filter chats based on selected tab (0: classmate, 1: teacher, 2: group)
    String typeFilter = _selectedChatTab == 0
        ? 'classmate'
        : _selectedChatTab == 1
            ? 'teacher'
            : 'group';
    List<Map<String, dynamic>> filteredChats =
        _chats.where((c) => c['chat_type'] == typeFilter).toList();

    return Stack(
      key: const ValueKey(2),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: EdgeInsets.fromLTRB(
                    padding, size.height * 0.02, padding, 0),
                child: _buildHeader('Messages', textColor)),
            SizedBox(height: size.height * 0.02),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: _buildLiquidGlassChatTabs(isDark)),
            SizedBox(height: size.height * 0.02),
            Expanded(
              child: _isLoadingChats
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF32C5FF)))
                  : filteredChats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  _selectedChatTab == 0
                                      ? Icons.person_outline
                                      : _selectedChatTab == 1
                                          ? Icons.school_outlined
                                          : Icons.groups_outlined,
                                  size: 64,
                                  color:
                                      isDark ? Colors.white30 : Colors.black26),
                              const SizedBox(height: 16),
                              Text(
                                  _selectedChatTab == 0
                                      ? 'No classmates added yet'
                                      : _selectedChatTab == 1
                                          ? 'No teachers added yet'
                                          : 'No groups created yet',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontSize: 16,
                                      fontFamily: 'Google Sans Flex')),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                              bottom: size.height * 0.22,
                              left: padding,
                              right: padding),
                          itemCount: filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = filteredChats[index];
                            return GestureDetector(
                              onLongPress: () => _deleteChat(
                                  chat['id'],
                                  chat[
                                      'chat_name']), // 🚀 Long press to delete permanent chat
                              child: _buildChatTile(chat['id'],
                                  chat['chat_name'], chat['chat_type'], isDark),
                            );
                          },
                        ),
            ),
          ],
        ),
        Positioned(
          right: padding,
          bottom: size.height * 0.22,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showAddChatDialog(isDark, _accentBlue);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: _accentBlue.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiquidGlassChatTabs(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.8),
                width: 1.2),
          ),
          child: Row(
            children: [
              _buildChatTabItem(0, 'Classmates', Icons.person_outline, isDark),
              _buildChatTabItem(1, 'Teachers', Icons.school_outlined, isDark),
              _buildChatTabItem(2, 'Groups', Icons.groups_outlined, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTabItem(
      int index, String title, IconData icon, bool isDark) {
    final selected = _selectedChatTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedChatTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? _accentBlue.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? _accentBlue
                      : (isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected
                            ? _accentBlue
                            : (isDark ? Colors.white70 : Colors.black54),
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                        fontFamily: 'Google Sans Flex')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(
      String id, String name, String type, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: id,
              chatName: name,
              chatType: type,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _accentBlue.withOpacity(0.2),
              child: Icon(
                type == 'teacher'
                    ? Icons.school
                    : type == 'group'
                        ? Icons.groups
                        : Icons.person,
                color: _accentBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Google Sans Flex')),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddChatDialog(bool isDark, Color accentColor) async {
    final nameCtrl = TextEditingController();
    String selectedType = 'classmate';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add conversation',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Google Sans Flex')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Alex or Science Group',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'classmate', child: Text('Classmate')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                  DropdownMenuItem(value: 'group', child: Text('Group')),
                ],
                onChanged: (value) =>
                    setDialogState(() => selectedType = value ?? 'classmate'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  await supabase.from('chats').insert({
                    'chat_name': name,
                    'chat_type': selectedType,
                  });
                  if (context.mounted) Navigator.pop(context);
                  _fetchChatsFromSupabase();
                } catch (e) {
                  _showGlassSnackBar('Failed to add conversation.',
                      isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsScreenContent(
      Size size, double padding, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: EdgeInsets.fromLTRB(
          padding, size.height * 0.02, padding, size.height * 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Settings', textColor),
          SizedBox(height: size.height * 0.03),
          _buildSettingCard(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: _userName,
              onTap: () => _showProfileDialog(isDark, _accentBlue)),
          const SizedBox(height: 12),
          _buildSettingCard(
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              title: 'Appearance',
              subtitle: isDark ? 'Dark mode' : 'Light mode',
              onTap: () => themeNotifier.value =
                  isDark ? ThemeMode.light : ThemeMode.dark),
          const SizedBox(height: 12),
          _buildSettingCard(
              icon: Icons.info_outline,
              title: 'About Lodha Inspiro',
              subtitle: 'Student portal & learning tools',
              onTap: () => _showGlassSnackBar(
                  'Lodha Inspiro is evolving into a student super-app. ✨')),
          const SizedBox(height: 12),
          _buildSettingCard(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: 'End your current session',
              onTap: _signOut),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(.14), shape: BoxShape.circle),
              child: Icon(icon, color: _accentBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Google Sans Flex')),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                          fontFamily: 'Google Sans Flex')),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassDrawer(Size size, bool isDark) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: isDark
                  ? Colors.black.withOpacity(.7)
                  : Colors.white.withOpacity(.85),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lodha Inspiro',
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Google Sans Flex')),
                  const SizedBox(height: 6),
                  Text(_userEmail,
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                          fontFamily: 'Google Sans Flex')),
                  const SizedBox(height: 28),
                  ListTile(
                    leading: const Icon(Icons.home_rounded, color: _accentBlue),
                    title: const Text('Home'),
                    onTap: () {
                      setState(() => _currentIndex = 0);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_rounded,
                        color: _accentBlue),
                    title: const Text('Inspiro AI'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InspiroAiScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded,
                        color: _accentBlue),
                    title: const Text('Notebooks'),
                    onTap: () {
                      setState(() => _currentIndex = 1);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.chat_bubble_outline_rounded, color: _accentBlue),
                    title: const Text('Messages'),
                    onTap: () {
                      setState(() => _currentIndex = 2);
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: const Text('Sign out'),
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidGlassNavBar(Size size, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showGlassSnackBar('Announcements coming soon! 🚀'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.8),
                        width: 1.2)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        size: 22),
                    const SizedBox(width: 8),
                    Text('Announcements',
                        style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF1E1E1E),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Google Sans Flex')),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.45)
                      : const Color(0xFFD6E2EA).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.7),
                      width: 1.5)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGlassNavItem(0, Icons.home_rounded, 'Home', isDark),
                  _buildGlassNavItem(
                      1, Icons.auto_awesome_rounded, 'Notebooks', isDark),
                  _buildGlassNavItem(
                      2, Icons.chat_bubble_outline_rounded, 'Chat', isDark),
                  _buildGlassNavItem(
                      3, Icons.settings_outlined, 'Settings', isDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassNavItem(
      int index, IconData icon, String label, bool isDark) {
    final selected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
              color: selected ? _accentBlue.withOpacity(.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(26)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? _accentBlue
                      : (isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 3),
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected
                          ? _accentBlue
                          : (isDark ? Colors.white70 : Colors.black54),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      fontFamily: 'Google Sans Flex')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProfileDialog(bool isDark, Color accentColor) async {
    final controller = TextEditingController(text: _userName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Your profile',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _updateUserName(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: accentColor, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
