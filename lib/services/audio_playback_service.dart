import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;

class AudioPlaybackService {
  final ja.AudioPlayer _player = ja.AudioPlayer();

  bool get isPlaying => _player.playing;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> setFile(String filePath) async {
    await _player.setFilePath(filePath);
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  void dispose() {
    _player.dispose();
  }
}
