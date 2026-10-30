import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'config.dart';
import 'logo.dart';
import 'theme.dart';

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
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(), password: pass.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = _msg(e.code));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _reset() async {
    if (email.text.trim().isEmpty) {
      setState(() {
        error = 'Type your email above first.';
        info = null;
      });
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.text.trim());
      setState(() {
        info = 'Password reset email sent.';
        error = null;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = _msg(e.code);
        info = null;
      });
    }
  }

  Widget _feature(IconData i, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(i, color: const Color(0xFF7FD6D1), size: 20)),
          const SizedBox(width: 12),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 15.5)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!wide) ...[
                  const Center(child: ClinicLogo(height: 96)),
                  const SizedBox(height: 14),
                  const Text(Cfg.clinicName,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),
                ],
                const Text('Welcome back',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text('Sign in to continue to your workspace',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 28),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        deco('Email address', icon: Icons.email_outlined)),
                const SizedBox(height: 14),
                TextField(
                  controller: pass,
                  obscureText: hide,
                  onSubmitted: (_) => _login(),
                  decoration:
                      deco('Password', icon: Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                        icon: Icon(hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => hide = !hide)),
                  ),
                ),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(error!,
                                style: const TextStyle(color: AppColors.red)))
                      ])),
                if (info != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(info!,
                          style: const TextStyle(color: AppColors.green))),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy ? null : _login,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                    onPressed: _reset, child: const Text('Forgot password?')),
              ]),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(children: [
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(56),
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                    AppColors.navy,
                    AppColors.navy2,
                    AppColors.tealDark
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LogoBadge(size: 96),
                        const SizedBox(height: 26),
                        const Text(Cfg.clinicName,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                height: 1.1)),
                        const SizedBox(height: 10),
                        const Text('Clinic management, made effortless.',
                            style: TextStyle(
                                color: Color(0xFFCFE6EA), fontSize: 18)),
                        const SizedBox(height: 40),
                        _feature(Icons.how_to_reg, 'Fast patient registration'),
                        _feature(Icons.event_available,
                            'Appointments you never miss'),
                        _feature(Icons.receipt_long,
                            'Instant receipts - print or PDF'),
                        _feature(Icons.insights, 'Live reports for management'),
                      ]),
                ),
              ),
              Expanded(flex: 4, child: form),
            ])
          : form,
    );
  }
}
