import 'dart:ui';

import 'package:flutter/cupertino.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Color _accentBlue = const Color(0xFF4B8DFF);
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      _showToast('Please fill in all fields', error: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isSignUp) {
        await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {'username': email.split('@').first},
        );
        _showToast('Account created! You can now sign in.');
        if (mounted) setState(() => _isSignUp = false);
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      _showToast(e.message, error: true);
    } catch (_) {
      _showToast('An unexpected error occurred', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? CupertinoColors.systemRed : _accentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_supabase.auth.currentSession != null) {
      return const HomeScreen();
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF172033);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF080B12) : const Color(0xFFF2F5F9),
      body: Stack(
        children: [
          Positioned(
            top: -150,
            left: -120,
            child: _orb(360, const Color(0xFF4B8DFF)),
          ),
          Positioned(
            bottom: -160,
            right: -130,
            child: _orb(380, const Color(0xFF9A7BFF)),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withOpacity(.07)
                            : Colors.white.withOpacity(.70),
                        borderRadius: BorderRadius.circular(38),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withOpacity(.13)
                              : Colors.white,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.08),
                            blurRadius: 35,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4B8DFF),
                                  Color(0xFF9A7BFF),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accentBlue.withOpacity(.25),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.sparkles,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Lodha Inspiro',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _isSignUp
                                ? 'Create your student space.'
                                : 'Your fluid study space, ready.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground.withOpacity(.58),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _glassTextField(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: CupertinoIcons.mail,
                            dark: dark,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _glassTextField(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: CupertinoIcons.lock,
                            dark: dark,
                            obscureText: true,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: CupertinoButton.filled(
                              borderRadius: BorderRadius.circular(20),
                              padding: EdgeInsets.zero,
                              onPressed: _isLoading ? null : _submitAuth,
                              child: _isLoading
                                  ? const CupertinoActivityIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      _isSignUp ? 'Sign Up' : 'Sign In',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isSignUp = !_isSignUp);
                            },
                            child: Text.rich(
                              TextSpan(
                                text: _isSignUp
                                    ? 'Already have an account? '
                                    : "Don't have an account? ",
                                style: TextStyle(
                                  color: foreground.withOpacity(.58),
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: _isSignUp ? 'Sign In' : 'Sign Up',
                                    style: TextStyle(
                                      color: _accentBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _glassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool dark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withOpacity(.24)
            : Colors.white.withOpacity(.52),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.white,
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(
            icon,
            size: 20,
            color: dark ? Colors.white60 : Colors.black45,
          ),
        ),
        placeholder: hint,
        placeholderStyle: TextStyle(
          color: dark ? Colors.white54 : Colors.black45,
        ),
        style: TextStyle(
          color: dark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: const BoxDecoration(),
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(.15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.18),
            blurRadius: 100,
            spreadRadius: 25,
          ),
        ],
      ),
    );
  }
}