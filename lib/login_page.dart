import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false, hide = true;
  String? error, info;

  String _msg(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return 'Login failed ($code).';
    }
  }

  Future<void> _login() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    setState(() { busy = true; error = null; info = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: pass.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = _msg(e.code));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reset() async {
    if (email.text.trim().isEmpty) {
      setState(() { error = 'Type your email above first.'; info = null; });
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text.trim());
      setState(() { info = 'Password reset email sent.'; error = null; });
    } on FirebaseAuthException catch (e) {
      setState(() { error = _msg(e.code); info = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.medical_services_outlined, size: 54, color: cs.primary),
                  const SizedBox(height: 8),
                  Text(Cfg.clinicName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Management System', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pass, obscureText: hide, onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(),
                      suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)),
                    ),
                  ),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: cs.error))),
                  if (info != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(info!, style: const TextStyle(color: Colors.green))),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : _login,
                    child: Padding(padding: const EdgeInsets.all(12), child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign In')),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Forgot password?')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
