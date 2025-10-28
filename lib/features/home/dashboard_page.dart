import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/supabase_bootstrap.dart';
import '../auth/signin_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session == null && mounted) {
        // Redirect to SignIn if the session becomes null
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (route) => false,
        );
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    final email = session?.user.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connecté en tant que: $email'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await supabase.auth.signOut();
              },
              child: const Text('Déconnexion'),
            ),
          ],
        ),
      ),
    );
  }
}

