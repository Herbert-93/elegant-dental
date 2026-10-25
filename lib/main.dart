import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'models.dart';
import 'services.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  // More compatible connection mode for networks/proxies that block Firestore's default streaming.
  FirebaseFirestore.instance.settings =
      const Settings(webExperimentalForceLongPolling: true);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: Cfg.clinicName,
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final u = s.data;
          if (u == null) return const LoginPage();
          return ProfileGate(key: ValueKey(u.uid), uid: u.uid);
        },
      );
}

/// Loads the user's role from Firestore and sends them to the right side.
class ProfileGate extends StatefulWidget {
  final String uid;
  const ProfileGate({super.key, required this.uid});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final Future<AppUser?> future = Svc.loadUser(widget.uid);

  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser?>(
        future: future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = s.data;
          if (s.hasError || user == null || !user.active) {
            return Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.block, size: 48, color: AppColors.red),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SelectableText(
                      s.hasError
                          ? 'Could not load your profile.\n\nDetails: ${s.error}\n\nUser ID: ${widget.uid}\n\nCheck: 1) Firestore rules are published  2) Firestore database is created  3) projectId in firebase_options.dart is correct.'
                          : 'Your account has no access or is deactivated.\nMake sure Firestore has users/${widget.uid} with role, active=true (boolean).',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Sign out')),
                ]),
              ),
            );
          }
          // Role decides which side is built. Operations users NEVER get AdminHome.
          return user.isAdmin
              ? AdminHome(user: user)
              : OperationsHome(user: user);
        },
      );
}
