import 'package:flutter/material.dart';

class ProfileDataPage extends StatelessWidget {
  const ProfileDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Mes données')),
      body: const Center(
        child: Text(
          'Work in progress',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
