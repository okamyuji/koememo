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
    final transcript = ref.watch(liveTranscriptProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('録音'),
        leading: isRecording || isProcessing
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            WaveformIndicator(isRecording: isRecording),
            const SizedBox(height: 32),
            if (isRecording || transcript.isNotEmpty)
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  reverse: true,
                  child: LiveTranscriptView(transcript: transcript),
                ),
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
      floatingActionButton: isProcessing
          ? const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: CircularProgressIndicator(),
            )
          : FloatingActionButton.large(
              onPressed: () => _handleFabPress(context, ref, isRecording),
              child: Icon(isRecording ? Icons.stop : Icons.mic, size: 36),
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
        final result = await ref
            .read(recordingControllerProvider.notifier)
            .stopRecording();
        if (context.mounted && result != null) {
          context.go('/');
        }
      } else {
        await ref.read(recordingControllerProvider.notifier).startRecording();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }
}
