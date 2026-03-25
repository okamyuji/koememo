import 'dart:async';
import 'package:flutter/material.dart';
import 'package:koememo/features/memo_detail/memo_detail_controller.dart';
import 'package:koememo/services/audio_playback_service.dart';

class AudioPlayerBar extends StatefulWidget {
  final String filePath;
  const AudioPlayerBar({super.key, required this.filePath});

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  late AudioPlaybackService _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlaybackService();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final absPath = await resolveAudioPath(widget.filePath);
    await _player.setFile(absPath);
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((dur) {
        if (mounted && dur != null) setState(() => _duration = dur);
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (_isPlaying) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
            ),
            Text(_formatDuration(_position)),
            Expanded(
              child: Slider(
                value: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds / _duration.inMilliseconds
                    : 0,
                onChanged: (value) {
                  final position = Duration(
                    milliseconds: (value * _duration.inMilliseconds).toInt(),
                  );
                  _player.seek(position);
                },
              ),
            ),
            Text(_formatDuration(_duration)),
          ],
        ),
      ),
    );
  }
}
