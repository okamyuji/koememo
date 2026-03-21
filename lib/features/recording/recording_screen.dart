import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koememo/features/recording/recording_controller.dart';
import 'package:koememo/features/recording/widgets/live_transcript_view.dart';
import 'package:koememo/features/recording/widgets/waveform_indicator.dart';
import 'package:koememo/models/recording_state.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  String _liveTranscript = '';

  @override
  void initState() {
    super.initState();
    final controller = ref.read(recordingControllerProvider.notifier);
    controller.liveTranscript.listen((text) {
      if (mounted) setState(() => _liveTranscript = text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingControllerProvider);
    final isRecording = recordingState is Recording;
    final isProcessing = recordingState is RecordingProcessing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('録音'),
        leading: isRecording
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            WaveformIndicator(isRecording: isRecording),
            const SizedBox(height: 32),
            if (isRecording || _liveTranscript.isNotEmpty)
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  reverse: true,
                  child: LiveTranscriptView(transcript: _liveTranscript),
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
          ? const CircularProgressIndicator()
          : FloatingActionButton.large(
              onPressed: () async {
                try {
                  if (isRecording) {
                    await ref
                        .read(recordingControllerProvider.notifier)
                        .stopRecording();
                    if (context.mounted) context.pop();
                  } else {
                    await ref
                        .read(recordingControllerProvider.notifier)
                        .startRecording();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('エラー: $e')));
                  }
                }
              },
              child: Icon(isRecording ? Icons.stop : Icons.mic, size: 36),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
