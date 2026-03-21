import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:koememo/core/constants.dart';
import 'package:koememo/core/utils/pcm_converter.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSubscription;
  bool _isRecording = false;
  String? _currentFilePath;
  final List<int> _pcmBuffer = [];

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  void Function(Float32List samples)? onAudioData;

  Future<String> startRecording() async {
    if (_isRecording) throw StateError('Already recording');

    final dir = await getApplicationDocumentsDirectory();
    final memosDir = Directory(p.join(dir.path, 'memos'));
    if (!await memosDir.exists()) {
      await memosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = p.join(memosDir.path, 'memo_$timestamp.wav');
    _pcmBuffer.clear();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate,
        numChannels: AppConstants.numChannels,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: true,
      ),
    );

    _isRecording = true;

    _audioStreamSubscription = stream.listen((data) {
      _pcmBuffer.addAll(data);
      final float32Data = PcmConverter.int16BytesToFloat32(
        Uint8List.fromList(data),
      );
      onAudioData?.call(float32Data);
    });

    return _currentFilePath!;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _recorder.stop();
    _isRecording = false;

    if (_currentFilePath != null && _pcmBuffer.isNotEmpty) {
      await _writeWavFile(_currentFilePath!, _pcmBuffer);
    }

    return _currentFilePath;
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  void dispose() {
    _audioStreamSubscription?.cancel();
    _recorder.dispose();
  }

  Future<void> _writeWavFile(String path, List<int> pcmBytes) async {
    final dataLength = pcmBytes.length;
    final fileLength = dataLength + 36;

    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileLength, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, AppConstants.numChannels, Endian.little);
    header.setUint32(24, AppConstants.sampleRate, Endian.little);
    header.setUint32(
      28,
      AppConstants.sampleRate * AppConstants.numChannels * 2,
      Endian.little,
    ); // byte rate
    header.setUint16(
      32,
      AppConstants.numChannels * 2,
      Endian.little,
    ); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);

    final file = File(path);
    final sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(Uint8List.fromList(pcmBytes));
    await sink.flush();
    await sink.close();
  }
}
