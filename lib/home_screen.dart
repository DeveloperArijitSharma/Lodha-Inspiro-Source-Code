import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'main.dart';
import 'notebooks/notebooks_list_screen.dart';
import 'classroom/classroom_screen.dart';
import 'classroom/teacher_recordings_screen.dart';
import 'app_preferences.dart';
import 'widgets/advanced_settings_section.dart';

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
    if (hapticsNotifier.value) HapticFeedback.heavyImpact();
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
    if (hapticsNotifier.value) HapticFeedback.mediumImpact();
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
                duration: smoothMotionNotifier.value
                    ? const Duration(milliseconds: 180)
                    : Duration.zero,
                child: _buildCurrentView(size, padding, isDark,
                    key: ValueKey<int>(_currentIndex)),
              ),
            ),
            if (_currentIndex != 4)
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
        return const NotebooksListScreen();
      case 3:
        return _buildChatTabContent(size, padding, isDark);
      case 4:
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
    return Padding(
      key: const ValueKey(1),
      padding: EdgeInsets.only(bottom: size.height * 0.11),
      child: const ClassroomScreen(),
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
              if (hapticsNotifier.value) HapticFeedback.lightImpact();
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
              _buildChatTabItem(0, 'Classmates', isDark),
              _buildChatTabItem(1, 'Teachers', isDark),
              _buildChatTabItem(2, 'Groups', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTabItem(int index, String label, bool isDark) {
    bool isSelected = _selectedChatTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (hapticsNotifier.value) HapticFeedback.selectionClick();
          setState(() => _selectedChatTab = index);
        },
        child: AnimatedContainer(
          duration: smoothMotionNotifier.value
              ? const Duration(milliseconds: 160)
              : Duration.zero,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withOpacity(0.2) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 5)
                  ]
                : [],
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white54 : Colors.black54),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    fontFamily: 'Google Sans Flex')),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(
      String chatId, String title, String chatType, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ChatScreen(
                      chatId: chatId, chatName: title, chatType: chatType),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: _accentBlue.withOpacity(0.2),
                child: Icon(
                    chatType == 'classmate'
                        ? Icons.person
                        : chatType == 'teacher'
                            ? Icons.school
                            : Icons.group,
                    color: _accentBlue)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Google Sans Flex')),
                  const SizedBox(height: 4),
                  Text('Tap to chat... (Long press to delete)',
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                          fontFamily: 'Google Sans Flex')),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: isDark ? Colors.white30 : Colors.black26, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsScreenContent(Size size, double padding, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return SingleChildScrollView(
      key: const ValueKey(3),
      padding: EdgeInsets.fromLTRB(
          padding, size.height * 0.02, padding, size.height * 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Settings', textColor),
          SizedBox(height: size.height * 0.03),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 30,
                    backgroundColor: _accentBlue.withOpacity(0.2),
                    child: Icon(Icons.person_rounded,
                        color: _accentBlue, size: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Google Sans Flex')),
                      const SizedBox(height: 2),
                      Text(_userEmail,
                          style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                              fontFamily: 'Google Sans Flex')),
                    ],
                  ),
                ),
                IconButton(
                    icon: Icon(Icons.edit_rounded, color: _accentBlue),
                    onPressed: () => _showEditNameDialog(isDark),
                    tooltip: 'Change Display Name'),
              ],
            ),
          ),
          SizedBox(height: size.height * 0.025),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: _accentBlue),
                    const SizedBox(width: 12),
                    Text('Light Mode',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Google Sans Flex')),
                  ],
                ),
                Switch.adaptive(
                  value: !isDark,
                  activeColor: _accentBlue,
                  onChanged: (value) {
                    if (hapticsNotifier.value) HapticFeedback.selectionClick();
                    themeNotifier.value =
                        value ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: size.height * 0.025),
          AdvancedSettingsSection(
            isDark: isDark,
            accentColor: _accentBlue,
          ),
          SizedBox(height: size.height * 0.025),
          SizedBox(
            width: double.infinity,
            height: size.height * 0.065,
            child: ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text('Sign Out',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Google Sans Flex')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassDrawer(Size size, bool isDark) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(40)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.5),
                border: Border(
                    right: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.8),
                        width: 1.5))),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.06,
                    vertical: size.height * 0.02),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                            radius: size.width * 0.075,
                            backgroundColor: _accentBlue.withOpacity(0.2),
                            child: Icon(Icons.person_rounded,
                                color: _accentBlue, size: 28)),
                        SizedBox(width: size.width * 0.04),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userName,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: size.width * 0.045,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Google Sans Flex')),
                              SizedBox(height: size.height * 0.003),
                              Text(_userEmail,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                      fontSize: size.width * 0.03,
                                      fontFamily: 'Google Sans Flex'),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: size.height * 0.02),
                    Divider(
                        color: isDark ? Colors.white12 : Colors.black12,
                        thickness: 1.5),
                    SizedBox(height: size.height * 0.02),
                    _buildSidebarItem(
                        icon: Icons.home_rounded,
                        title: 'Dashboard',
                        index: 0,
                        isDark: isDark),
                    SizedBox(height: size.height * 0.01),
                    _buildSidebarItem(
                        icon: Icons.assignment_rounded,
                        title: 'Classwork',
                        index: 1,
                        isDark: isDark),
                    SizedBox(height: size.height * 0.01),
                    ListTile(
                      leading: Icon(Icons.auto_awesome_rounded, color: isDark ? Colors.white60 : Colors.black54),
                      title: const Text('Notebooks', style: TextStyle(fontFamily: 'Google Sans Flex')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotebooksListScreen()));
                      },
                    ),
                    SizedBox(height: size.height * 0.01),
                    _buildSidebarItem(
                        icon: Icons.chat_bubble_rounded,
                        title: 'Messages',
                        index: 3,
                        isDark: isDark),
                    SizedBox(height: size.height * 0.01),
                    _buildSidebarItem(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        index: 4,
                        isDark: isDark),
                    if (supabase.auth.currentUser?.userMetadata?['role']?.toString() == 'teacher') ...[
                      SizedBox(height: size.height * 0.01),
                      ListTile(
                        leading: Icon(Icons.video_library_rounded, color: isDark ? Colors.white60 : Colors.black54),
                        title: const Text('Student recordings', style: TextStyle(fontFamily: 'Google Sans Flex')),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRecordingsScreen()));
                        },
                      ),
                    ],
                    const Spacer(),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded,
                          color: Colors.redAccent),
                      title: const Text('Sign Out',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Google Sans Flex')),
                      onTap: _signOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
      {required IconData icon,
      required String title,
      required int index,
      required bool isDark}) {
    bool isSelected = _currentIndex == index;
    return Container(
      decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.7))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: isDark ? Colors.white24 : Colors.white, width: 1.5)
              : null),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected
                ? _accentBlue
                : (isDark ? Colors.white60 : Colors.black54)),
        title: Text(title,
            style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Google Sans Flex')),
        onTap: () {
          setState(() => _currentIndex = index);
          Navigator.pop(context);
        },
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
                      1, Icons.assignment_rounded, 'Classwork', isDark),
                  _buildGlassNavItem(
                      2, Icons.auto_awesome_rounded, 'Notebook', isDark),
                  _buildGlassNavItem(
                      3, Icons.chat_bubble_outline_rounded, 'Chat', isDark),
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
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (hapticsNotifier.value) HapticFeedback.lightImpact();
          setState(() => _currentIndex = index);
        },
        child: AnimatedContainer(
          duration: smoothMotionNotifier.value ? const Duration(milliseconds: 160) : Duration.zero,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.85))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white54 : const Color(0xFF445566)),
                  size: 24),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white54 : const Color(0xFF445566)),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontFamily: 'Google Sans Flex')),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddChatDialog(bool isDark, Color accentColor) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController groupController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Future<void> handleAddUser() async {
            final email = emailController.text.trim();
            if (email.isEmpty) return;

            String typeStr = _selectedChatTab == 0
                ? 'classmate'
                : _selectedChatTab == 1
                    ? 'teacher'
                    : 'group';
            String chatName =
                _selectedChatTab == 2 ? groupController.text.trim() : email;

            if (chatName.isEmpty) return;

            setStateDialog(() => isLoading = true);
            try {
              if (_selectedChatTab != 2) {
                final userExists = await supabase
                    .rpc('check_email_exists', params: {'lookup_email': email});
                if (userExists != true) {
                  Navigator.pop(context);
                  _showGlassSnackBar('User not found. They must sign up first!',
                      isError: true);
                  return;
                }
              }

              // 🚀 SAVE CHAT PERMANENTLY TO SUPABASE
              await supabase.from('chats').insert({
                'chat_name': chatName,
                'chat_type': typeStr,
              });

              Navigator.pop(context);
              _fetchChatsFromSupabase();
              _showGlassSnackBar('Chat created successfully! ✨');
            } catch (e) {
              Navigator.pop(context);
              _showGlassSnackBar('Database error saving chat.', isError: true);
            }
          }

          if (_selectedChatTab == 0 || _selectedChatTab == 1) {
            return _GlassDialogBase(
              isDark: isDark,
              accentColor: accentColor,
              isLoading: isLoading,
              title:
                  _selectedChatTab == 0 ? 'Add Classmate' : 'Chat with Teacher',
              icon: _selectedChatTab == 0
                  ? Icons.person_add_rounded
                  : Icons.school_rounded,
              actionText: 'Start Chat',
              content: _buildGlassTextField(
                  controller: emailController,
                  hintText: 'Registered Email Address',
                  icon: Icons.email_outlined,
                  isDark: isDark),
              onAction: handleAddUser,
            );
          } else {
            return _GlassDialogBase(
              isDark: isDark,
              accentColor: accentColor,
              isLoading: isLoading,
              title: 'Create Group',
              icon: Icons.group_add_rounded,
              actionText: 'Create',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGlassTextField(
                      controller: groupController,
                      hintText: 'Group Name',
                      icon: Icons.title_rounded,
                      isDark: isDark),
                ],
              ),
              onAction: handleAddUser,
            );
          }
        });
      },
    );
  }

  void _showEditNameDialog(bool isDark) {
    final nameController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return _GlassDialogBase(
          isDark: isDark,
          accentColor: _accentBlue,
          title: 'Change Display Name',
          icon: Icons.badge_rounded,
          actionText: 'Save',
          content: _buildGlassTextField(
              controller: nameController,
              hintText: 'New Display Name',
              icon: Icons.person_outline_rounded,
              isDark: isDark),
          onAction: () async {
            if (hapticsNotifier.value) HapticFeedback.mediumImpact();
            Navigator.pop(context);
            await _updateUserName(nameController.text);
          },
        );
      },
    );
  }

  Widget _buildGlassTextField(
      {required TextEditingController controller,
      required String hintText,
      required IconData icon,
      required bool isDark,
      int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.3)
              : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.white70)),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontFamily: 'Google Sans Flex'),
        decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontFamily: 'Google Sans Flex'),
            prefixIcon:
                Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      ),
    );
  }
}

class _GlassDialogBase extends StatelessWidget {
  final bool isDark;
  final Color accentColor;
  final String title;
  final IconData icon;
  final Widget content;
  final String actionText;
  final VoidCallback onAction;
  final bool isLoading;

  const _GlassDialogBase(
      {required this.isDark,
      required this.accentColor,
      required this.title,
      required this.icon,
      required this.content,
      required this.actionText,
      required this.onAction,
      this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E).withOpacity(0.6)
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.9),
                        width: 1.5)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: Icon(icon, color: accentColor, size: 32)),
                    const SizedBox(height: 16),
                    Text(title,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Google Sans Flex')),
                    const SizedBox(height: 20),
                    content,
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                            child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.white70
                                        : Colors.black54),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Google Sans Flex')))),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 2,
                            child: ElevatedButton(
                                onPressed: isLoading ? null : onAction,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    elevation: 0),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : Text(actionText,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Google Sans Flex')))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
