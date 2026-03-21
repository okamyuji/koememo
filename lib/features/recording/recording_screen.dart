import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koememo/features/recording/recording_controller.dart';
import 'package:koememo/features/recording/widgets/live_transcript_view.dart';
import 'package:koememo/features/recording/widgets/waveform_indicator.dart';
import 'package:koememo/models/recording_state.dart';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingControllerProvider);
    final isRecording = recordingState is Recording;
    final isProcessing = recordingState is RecordingProcessing;
    final isInitializing = recordingState is RecordingInitializing;
    final isIdle = recordingState is RecordingIdle;
    final isBusy = isProcessing || isInitializing;
    final transcript = ref.watch(liveTranscriptProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isInitializing
              ? '準備中...'
              : isRecording
              ? '録音中...'
              : isProcessing
              ? '処理中...'
              : '録音',
        ),
        leading: isIdle
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              )
            : const SizedBox.shrink(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            WaveformIndicator(isRecording: isRecording),
            const SizedBox(height: 32),
            if (isInitializing)
              const Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('音声認識モデルを準備中...'),
                    ],
                  ),
                ),
              )
            else if (isRecording)
              Expanded(
                flex: 3,
                child: transcript.isEmpty
                    ? Center(
                        child: Text(
                          '録音しています...',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : SingleChildScrollView(
                        reverse: true,
                        child: LiveTranscriptView(transcript: transcript),
                      ),
              )
            else if (isProcessing)
              const Expanded(
                flex: 3,
                child: Center(child: Text('メモを保存しています...')),
              )
            else
              const Expanded(
                flex: 3,
                child: Center(child: Text('マイクボタンを押して録音を開始')),
              ),
            const Spacer(),
          ],
        ),
      ),
      floatingActionButton: isBusy
          ? const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: CircularProgressIndicator(),
            )
          : FloatingActionButton.large(
              onPressed: () => _handleFabPress(context, ref, isRecording),
              backgroundColor: isRecording
                  ? Theme.of(context).colorScheme.error
                  : null,
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                size: 36,
                color: isRecording ? Colors.white : null,
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _handleFabPress(
    BuildContext context,
    WidgetRef ref,
    bool isRecording,
  ) async {
    try {
      if (isRecording) {
        await ref.read(recordingControllerProvider.notifier).stopRecording();
        if (context.mounted) context.go('/');
      } else {
        await ref.read(recordingControllerProvider.notifier).startRecording();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
