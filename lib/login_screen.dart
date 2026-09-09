import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _signup = false;

  @override
  void initState() {
    super.initState();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShellScreen()));
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _toast('Please fill in both fields.', error: true);
      return;
    }
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      if (_signup) {
        await _supabase.auth.signUp(email: email, password: password, data: {'username': email.split('@').first});
        _toast('Account created. You can sign in now.');
        setState(() => _signup = false);
      } else {
        await _supabase.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, backgroundColor: error ? Colors.redAccent : const Color(0xFF4B8DFF)));
  }

  @override
  Widget build(BuildContext context) {
    if (_supabase.auth.currentSession != null) return const AppShellScreen();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(backgroundColor: dark ? const Color(0xFF080C14) : const Color(0xFFF2F6FB), body: Stack(children: [
      Positioned(top: -130, left: -100, child: _orb(340, const Color(0xFF4B8DFF))),
      Positioned(bottom: -150, right: -120, child: _orb(360, const Color(0xFF9A7BFF))),
      Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 65, sigmaY: 65), child: Container(color: Colors.transparent))),
      SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ClipRRect(borderRadius: BorderRadius.circular(38), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: Container(padding: const EdgeInsets.fromLTRB(24, 28, 24, 24), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.07) : Colors.white.withOpacity(.68), borderRadius: BorderRadius.circular(38), border: Border.all(color: dark ? Colors.white.withOpacity(.13) : Colors.white, width: 1.3)), child: Column(children: [
        Container(width: 76, height: 76, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF4B8DFF), Color(0xFF9A7BFF)]), boxShadow: [BoxShadow(color: const Color(0xFF4B8DFF).withOpacity(.25), blurRadius: 30)]), child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 34)),
        const SizedBox(height: 18),
        Text('Lodha Inspiro', style: TextStyle(color: foreground, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_signup ? 'Create your student space.' : 'Your fluid study space, ready.', style: TextStyle(color: foreground.withOpacity(.58), fontSize: 14)),
        const SizedBox(height: 26),
        _Field(controller: _email, placeholder: 'Email', icon: CupertinoIcons.mail),
        const SizedBox(height: 12),
        _Field(controller: _password, placeholder: 'Password', icon: CupertinoIcons.lock, obscure: true),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: CupertinoButton.filled(onPressed: _loading ? null : _submit, borderRadius: BorderRadius.circular(22), padding: const EdgeInsets.symmetric(vertical: 15), child: _loading ? const CupertinoActivityIndicator(color: Colors.white) : Text(_signup ? 'Create account' : 'Continue'))),
        const SizedBox(height: 8),
        CupertinoButton(onPressed: _loading ? null : () => setState(() => _signup = !_signup), child: Text(_signup ? 'Already have an account? Sign in' : 'New here? Create an account')),
      ])))))));
  }

  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.18), boxShadow: [BoxShadow(color: color.withOpacity(.18), blurRadius: 90, spreadRadius: 25)]));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscure;
  const _Field({required this.controller, required this.placeholder, required this.icon, this.obscure = false});
  @override
  Widget build(BuildContext context) { final dark = Theme.of(context).brightness == Brightness.dark; return ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.07) : Colors.white.withOpacity(.72), borderRadius: BorderRadius.circular(20), border: Border.all(color: dark ? Colors.white12 : Colors.white)), child: TextField(controller: controller, obscureText: obscure, decoration: InputDecoration(prefixIcon: Icon(icon), hintText: placeholder, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16))))); }
}
