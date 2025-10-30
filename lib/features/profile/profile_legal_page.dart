import 'package:flutter/material.dart';

class ProfileLegalPage extends StatelessWidget {
  const ProfileLegalPage({
    super.key,
    required this.title,
    required this.heading,
    required this.body,
  });

  final String title;
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
