import 'package:flutter/material.dart';

class AccountCompletionPage extends StatelessWidget {
  const AccountCompletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter votre compte')),
      body: const Center(
        child: Text(
          'Page de complétion de compte (stub) — à remplir avec les infos profil et le choix de rôle.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

