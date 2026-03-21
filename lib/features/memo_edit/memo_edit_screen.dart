import 'package:flutter/material.dart';

class MemoEditScreen extends StatelessWidget {
  final int memoId;
  const MemoEditScreen({super.key, required this.memoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メモ編集')),
      body: Center(child: Text('メモ編集 #$memoId')),
    );
  }
}
