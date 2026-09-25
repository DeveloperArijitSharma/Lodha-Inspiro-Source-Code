import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isSignUp = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 🚀 GLOBAL LIGHT BLUE ACCENT COLOR
  final Color _accentBlue = const Color(0xFF32C5FF);

  @override
  void initState() {
    super.initState();
    // Setup auth state listener to automatically navigate to Home
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isSignUp) {
        await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': email.split('@')[0]
          }, // Default username from email
        );
        _showSuccess('Account created! You can now sign in.');
        setState(() => _isSignUp = false);
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // Successful login will trigger the onAuthStateChange listener
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _accentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If user is already logged in, show a blank loading screen while redirecting
    if (_supabase.auth.currentSession != null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: _accentBlue),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      body: Stack(
        children: [
          // ====================================================
          // 🎨 BACKGROUND ORBS (Makes the glass effect pop)
          // ====================================================
          Positioned(
            top: size.height * 0.1,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentBlue.withOpacity(isDark ? 0.4 : 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.05,
            right: -size.width * 0.3,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD3B4FF)
                    .withOpacity(isDark ? 0.3 : 0.4), // Soft purple contrast
              ),
            ),
          ),
          // Heavy blur over the background orbs
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),

          // ====================================================
          // 🧊 LIQUID GLASS LOGIN CARD
          // ====================================================
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.4)
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo / Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome_mosaic_rounded,
                              color: _accentBlue, size: 48),
                        ),
                        const SizedBox(height: 24),

                        // App Title
                        Text(
                          'Lodha Inspiro',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Google Sans Flex',
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp
                              ? 'Create your student account'
                              : 'Welcome back, student',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 15,
                            fontFamily: 'Google Sans Flex',
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Glass Text Fields
                        _buildGlassTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          icon: Icons.email_outlined,
                          isDark: isDark,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          icon: Icons.lock_outline_rounded,
                          isDark: isDark,
                          obscureText: true,
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    _isSignUp ? 'Sign Up' : 'Sign In',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Google Sans Flex'),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Toggle Mode Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isSignUp = !_isSignUp);
                          },
                          child: RichText(
                            text: TextSpan(
                              text: _isSignUp
                                  ? 'Already have an account? '
                                  : 'Don\'t have an account? ',
                              style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                  fontFamily: 'Google Sans Flex'),
                              children: [
                                TextSpan(
                                  text: _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: TextStyle(
                                      color: _accentBlue,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // 🧊 HELPER: GLASS TEXT FIELD
  // ====================================================
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.white70),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontFamily: 'Google Sans Flex'),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          prefixIcon:
              Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
