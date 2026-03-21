import 'package:flutter/material.dart';

class MemoDetailScreen extends StatelessWidget {
  final int memoId;
  const MemoDetailScreen({super.key, required this.memoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メモ詳細')),
      body: Center(child: Text('メモ #$memoId')),
    );
  }
}
