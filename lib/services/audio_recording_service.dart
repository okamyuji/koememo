import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:koememo/core/constants.dart';
import 'package:koememo/core/utils/pcm_converter.dart';

class AudioRecordingService {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  bool _isRecording = false;
  String? _currentFilePath;
  String? _relativeFilePath;
  final List<int> _pcmBuffer = [];

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;
  String? get relativeFilePath => _relativeFilePath;

  void Function(Float32List samples)? onAudioData;

  Future<bool> hasPermission() async {
    _recorder ??= AudioRecorder();
    return await _recorder!.hasPermission();
  }

  Future<String> startRecording() async {
    if (_isRecording) throw StateError('Already recording');

    _recorder ??= AudioRecorder();
    final dir = await getApplicationDocumentsDirectory();
    final memosDir = Directory(p.join(dir.path, 'memos'));
    if (!await memosDir.exists()) {
      await memosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _relativeFilePath = 'memos/memo_$timestamp.wav';
    _currentFilePath = p.join(dir.path, _relativeFilePath!);
    _pcmBuffer.clear();

    final stream = await _recorder!.startStream(
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
      if (_pcmBuffer.length < AppConstants.maxRecordingBytes) {
        _pcmBuffer.addAll(data);
      }
      final float32Data = PcmConverter.int16BytesToFloat32(data);
      onAudioData?.call(float32Data);
    });

    return _currentFilePath!;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _recorder?.stop();
    _isRecording = false;

    if (_currentFilePath != null && _pcmBuffer.isNotEmpty) {
      await _writeWavFile(_currentFilePath!, _pcmBuffer);
    }

    return _currentFilePath;
  }

  void dispose() {
    _audioStreamSubscription?.cancel();
    _recorder?.dispose();
    _recorder = null;
  }

  Future<void> _writeWavFile(String path, List<int> pcmBytes) async {
    final dataLength = pcmBytes.length;
    final fileLength = dataLength + 36;

    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileLength, Endian.little);
    // WAVE
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, AppConstants.numChannels, Endian.little);
    header.setUint32(24, AppConstants.sampleRate, Endian.little);
    header.setUint32(
      28,
      AppConstants.sampleRate * AppConstants.numChannels * 2,
      Endian.little,
    );
    header.setUint16(32, AppConstants.numChannels * 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    // data
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataLength, Endian.little);

    final file = File(path);
    final sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(Uint8List.fromList(pcmBytes));
    await sink.flush();
    await sink.close();
  }
}
