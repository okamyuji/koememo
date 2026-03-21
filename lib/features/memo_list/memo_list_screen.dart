import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MemoListScreen extends StatelessWidget {
  const MemoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: const Center(child: Text('メモがありません')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recording'),
        child: const Icon(Icons.mic),
      ),
    );
  }
}
