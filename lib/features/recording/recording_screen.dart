import 'package:flutter/material.dart';

class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('録音')),
      body: const Center(child: Text('録音画面')),
    );
  }
}
