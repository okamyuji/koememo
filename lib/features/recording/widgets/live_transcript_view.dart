import 'package:flutter/material.dart';

class LiveTranscriptView extends StatelessWidget {
  final String transcript;
  const LiveTranscriptView({super.key, required this.transcript});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: transcript.isEmpty
          ? Text(
              '録音を開始すると文字起こしが表示されます',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : SelectableText(
              transcript,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
    );
  }
}
