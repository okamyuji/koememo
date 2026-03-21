import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:koememo/database/app_database.dart';

class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;

  const MemoCard({super.key, required this.memo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(memo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (memo.transcript.isNotEmpty)
              Text(
                memo.transcript,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(memo.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: Icon(
          memo.audioFilePath != null ? Icons.mic : Icons.text_snippet,
          color: Theme.of(context).colorScheme.primary,
        ),
        isThreeLine: memo.transcript.isNotEmpty,
      ),
    );
  }
}
