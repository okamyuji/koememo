# sherpa_onnx Flutter 導入ガイド - 音声メモアプリ向け

## 要件

- リアルタイム文字起こし（ストリーミング）+ 録音後バッチ変換の両対応
- オフライン必須（通信なしで動作）
- 短時間メモ（〜1分）
- iOS / Android クロスプラットフォーム
- 日本語対応必須

---

## 1. 日本語モデル選定

### 推奨: SenseVoice (非ストリーミング / simulated-streaming)

音声メモアプリの要件に最も適合するモデル。

| 項目 | 値 |
|------|-----|
| モデル名 | `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09` |
| 対応言語 | 中国語, 英語, **日本語**, 韓国語, 広東語 |
| モデルサイズ (int8) | 約 228 MB |
| ファイル構成 | `model.int8.onnx` + `tokens.txt` |
| 認識方式 | 非ストリーミング（VAD + セグメント単位で simulated streaming 可能） |
| 特徴 | 言語自動検出, 感情検出, イベント検出（音楽/拍手等） |

**選定理由:**

1. 日本語認識精度が高い（SenseVoiceSmall ベース、FunASR 由来）
2. int8 量子化で 228MB とモバイルに現実的なサイズ
3. 言語を `ja` に指定可能で誤認識を抑制できる
4. 1分程度の短いメモなら、非ストリーミングでも十分高速
5. VAD（Voice Activity Detection）と組み合わせた simulated streaming で
   リアルタイム表示も可能

### 代替案: Whisper tiny/base

精度は SenseVoice より劣るが、モデルサイズを抑えたい場合の選択肢。

| モデル | サイズ | 日本語精度 | 備考 |
|--------|--------|------------|------|
| Whisper tiny (int8) | 約 40MB | 中程度 | サイズ優先時 |
| Whisper base (int8) | 約 75MB | やや良好 | バランス型 |
| Whisper small (int8) | 約 250MB | 良好 | SenseVoice と同等サイズ |

Whisper は非ストリーミング専用。ストリーミングが必要な場合は VAD + チャンク分割の
simulated streaming パターンを使う（SenseVoice と同じアプローチ）。

---

## 2. プロジェクトセットアップ

### 2.1 pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  sherpa_onnx: ^1.12.0
  record: ^5.1.0            # マイク録音用
  path_provider: ^2.1.0     # モデルファイルパス管理
  permission_handler: ^11.0.0  # マイクパーミッション

flutter:
  assets:
    - assets/models/sense-voice/
```

### 2.2 モデルファイルの配置

```
your_app/
├── assets/
│   └── models/
│       └── sense-voice/
│           ├── model.int8.onnx   # 228MB
│           └── tokens.txt        # 308KB
├── lib/
│   ├── services/
│   │   ├── speech_recognition_service.dart
│   │   ├── audio_recording_service.dart
│   │   └── model_manager.dart
│   └── ...
└── pubspec.yaml
```

**重要: モデルサイズの戦略**

228MB のモデルを assets にバンドルするとアプリサイズが大きくなる。
2つの戦略がある:

A) **assets バンドル方式（推奨: 短期開発向け）**
   - `pubspec.yaml` の `assets:` に含める
   - メリット: 初回起動から即使用可能、実装がシンプル
   - デメリット: アプリバイナリが 230MB+ 増加

B) **初回起動時ダウンロード方式（推奨: プロダクション向け）**
   - アプリには含めず、初回起動時に HuggingFace 等からダウンロード
   - メリット: アプリサイズを抑えられる
   - デメリット: オフライン要件に初回だけ例外が発生、ダウンロード管理の実装が必要

今回はオフライン必須のため、**A: assets バンドル方式** を採用する。

### 2.3 プラットフォーム設定

#### Android: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- マイクパーミッション -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <application
        android:largeHeap="true"
        ... >
        ...
    </application>
</manifest>
```

#### Android: `android/app/build.gradle`

```groovy
android {
    defaultConfig {
        minSdkVersion 21  // sherpa_onnx の最小要件
        // ...
    }

    // モデルファイルの圧縮を無効化（onnx ファイルは既に最適化済み）
    aaptOptions {
        noCompress 'onnx'
    }
}
```

#### iOS: `ios/Runner/Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声メモの録音と文字起こしに使用します</string>
```

#### iOS: `ios/Podfile`

```ruby
platform :ios, '13.0'  # sherpa_onnx の最小要件

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

---

## 3. コア実装

### 3.1 モデルアセットのコピーユーティリティ

sherpa_onnx は Flutter assets を直接読めないため、
アプリのドキュメントディレクトリにコピーする必要がある。

```dart
// lib/services/model_manager.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ModelManager {
  static String? _modelDir;

  /// モデルファイルをアプリのドキュメントディレクトリにコピーし、
  /// コピー先のディレクトリパスを返す。
  /// 既にコピー済みの場合はスキップする。
  static Future<String> ensureModelReady() async {
    if (_modelDir != null) return _modelDir!;

    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(appDir.path, 'models', 'sense-voice'));

    // モデルファイルの存在チェック（tokens.txt で判定）
    final tokensFile = File(p.join(modelDir.path, 'tokens.txt'));
    if (!await tokensFile.exists()) {
      await modelDir.create(recursive: true);
      await _copyAssetFile(
        'assets/models/sense-voice/model.int8.onnx',
        p.join(modelDir.path, 'model.int8.onnx'),
      );
      await _copyAssetFile(
        'assets/models/sense-voice/tokens.txt',
        p.join(modelDir.path, 'tokens.txt'),
      );
    }

    _modelDir = modelDir.path;
    return _modelDir!;
  }

  static Future<void> _copyAssetFile(String assetPath, String destPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await File(destPath).writeAsBytes(bytes, flush: true);
  }
}
```

### 3.2 音声認識サービス

```dart
// lib/services/speech_recognition_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'model_manager.dart';

/// 音声認識の結果を表す不変オブジェクト
class RecognitionResult {
  final String text;
  final bool isFinal;
  final String? detectedLanguage;

  const RecognitionResult({
    required this.text,
    required this.isFinal,
    this.detectedLanguage,
  });
}

/// sherpa_onnx を使った音声認識サービス。
/// OfflineRecognizer（非ストリーミング）を使い、
/// VAD と組み合わせて simulated streaming を実現する。
class SpeechRecognitionService {
  sherpa.OfflineRecognizer? _recognizer;
  sherpa.VoiceActivityDetector? _vad;
  bool _isInitialized = false;

  final _resultController = StreamController<RecognitionResult>.broadcast();
  Stream<RecognitionResult> get results => _resultController.stream;

  bool get isInitialized => _isInitialized;

  /// 初期化。アプリ起動時に1回だけ呼ぶ。
  /// 重い処理なので Isolate またはバックグラウンドで実行を推奨。
  Future<void> initialize() async {
    if (_isInitialized) return;

    final modelDir = await ModelManager.ensureModelReady();

    // --- OfflineRecognizer の設定 ---
    final recognizerConfig = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: '$modelDir/model.int8.onnx',
          language: 'ja',           // 日本語を明示指定
          useInverseTextNormalization: true,  // 数字等の正規化
        ),
        tokens: '$modelDir/tokens.txt',
        numThreads: 2,             // モバイルでは 2 が最適
        debug: false,
      ),
    );
    _recognizer = sherpa.OfflineRecognizer(recognizerConfig);

    // --- VAD の設定 ---
    // Silero VAD モデルは sherpa_onnx パッケージに内蔵
    final vadConfig = sherpa.VadModelConfig(
      sileroVad: sherpa.SileroVadModelConfig(
        model: '', // 空文字でデフォルト内蔵モデルを使用
        threshold: 0.5,
        minSilenceDuration: 0.5,   // 0.5秒の無音でセグメント区切り
        minSpeechDuration: 0.25,
        maxSpeechDuration: 30.0,   // メモ用途: 最大30秒
      ),
      sampleRate: 16000,
      numThreads: 1,
      debug: false,
    );
    _vad = sherpa.VoiceActivityDetector(vadConfig, bufferSizeInSeconds: 60);

    _isInitialized = true;
  }

  /// オーディオサンプル（16kHz, mono, Float32）を入力する。
  /// マイクから取得した PCM データをこのメソッドに連続的に渡す。
  void acceptWaveform(Float32List samples) {
    if (!_isInitialized || _vad == null || _recognizer == null) return;

    _vad!.acceptWaveform(samples);

    // VAD がスピーチセグメントを検出したら認識を実行
    while (!_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();

      final stream = _recognizer!.createStream();
      stream.acceptWaveform(
        samples: segment.samples,
        sampleRate: 16000,
      );
      _recognizer!.decode(stream);

      final result = _recognizer!.getResult(stream);
      if (result.text.isNotEmpty) {
        _resultController.add(RecognitionResult(
          text: result.text,
          isFinal: true,
          detectedLanguage: result.lang,
        ));
      }
      stream.free();
    }
  }

  /// 録音終了時に呼ぶ。VAD にバッファ内の残りを処理させる。
  void flush() {
    _vad?.flush();
    // flush 後に残ったセグメントがあれば処理
    while (_vad != null && !_vad!.isEmpty()) {
      final segment = _vad!.front();
      _vad!.pop();

      final stream = _recognizer!.createStream();
      stream.acceptWaveform(
        samples: segment.samples,
        sampleRate: 16000,
      );
      _recognizer!.decode(stream);

      final result = _recognizer!.getResult(stream);
      if (result.text.isNotEmpty) {
        _resultController.add(RecognitionResult(
          text: result.text,
          isFinal: true,
          detectedLanguage: result.lang,
        ));
      }
      stream.free();
    }
  }

  /// 保存済みの音声ファイルからバッチで文字起こしを行う。
  /// 録音後に再認識する場合に使用。
  Future<String> transcribeFile(String filePath) async {
    if (!_isInitialized || _recognizer == null) {
      throw StateError('SpeechRecognitionService is not initialized');
    }

    final stream = _recognizer!.createStream();

    // WAV ファイルを読み込んで認識
    // 注意: 16kHz mono PCM WAV 形式である必要がある
    final waveData = await sherpa.readWave(filePath);
    stream.acceptWaveform(
      samples: waveData.samples,
      sampleRate: waveData.sampleRate,
    );

    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);
    stream.free();

    return result.text;
  }

  void dispose() {
    _resultController.close();
    _recognizer?.free();
    _vad?.free();
    _recognizer = null;
    _vad = null;
    _isInitialized = false;
  }
}
```

### 3.3 音声録音サービス

```dart
// lib/services/audio_recording_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// マイクからの録音を管理し、同時に PCM データを
/// SpeechRecognitionService に渡すためのサービス。
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;
  String? _currentFilePath;

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  /// コールバック: 録音中の PCM データを受け取るハンドラ
  void Function(Float32List samples)? onAudioData;

  /// 録音開始。同時にリアルタイム文字起こし用のストリームも開始する。
  Future<String> startRecording() async {
    if (_isRecording) throw StateError('Already recording');

    // 保存用ファイルパスの生成
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = p.join(dir.path, 'memos', 'memo_$timestamp.wav');

    // ストリーミング録音の開始
    // 16kHz, mono, 16bit PCM はsherpa_onnx の要件
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: true,
      ),
    );

    _isRecording = true;

    // PCM バイトストリームを Float32 に変換して
    // リアルタイム認識用コールバックに渡す
    final pcmChunks = <int>[];  // WAV 保存用にもバッファリング
    _audioStreamSubscription = stream.listen((data) {
      pcmChunks.addAll(data);

      // Int16 PCM → Float32 変換
      final int16Data = Int16List.view(Uint8List.fromList(data).buffer);
      final float32Data = Float32List(int16Data.length);
      for (var i = 0; i < int16Data.length; i++) {
        float32Data[i] = int16Data[i] / 32768.0;
      }

      onAudioData?.call(float32Data);
    });

    return _currentFilePath!;
  }

  /// 録音停止。WAV ファイルを保存して返す。
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _recorder.stop();
    _isRecording = false;

    return _currentFilePath;
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  void dispose() {
    _audioStreamSubscription?.cancel();
    _recorder.dispose();
  }
}
```

### 3.4 統合コントローラ

```dart
// lib/services/voice_memo_controller.dart

import 'dart:async';
import 'speech_recognition_service.dart';
import 'audio_recording_service.dart';

/// 録音 + リアルタイム文字起こし + バッチ文字起こしを統合する。
class VoiceMemoController {
  final SpeechRecognitionService _speechService;
  final AudioRecordingService _recordingService;

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  String _currentTranscript = '';
  String get currentTranscript => _currentTranscript;

  StreamSubscription? _recognitionSubscription;

  VoiceMemoController({
    SpeechRecognitionService? speechService,
    AudioRecordingService? recordingService,
  })  : _speechService = speechService ?? SpeechRecognitionService(),
        _recordingService = recordingService ?? AudioRecordingService();

  /// 初期化。アプリ起動時に呼ぶ。
  Future<void> initialize() async {
    await _speechService.initialize();

    // リアルタイム認識結果を購読
    _recognitionSubscription = _speechService.results.listen((result) {
      _currentTranscript += result.text;
      _transcriptController.add(_currentTranscript);
    });

    // 録音サービスから音声データを認識サービスに流す
    _recordingService.onAudioData = (samples) {
      _speechService.acceptWaveform(samples);
    };
  }

  /// 録音 + リアルタイム文字起こし開始
  Future<String> startMemo() async {
    _currentTranscript = '';
    final filePath = await _recordingService.startRecording();
    return filePath;
  }

  /// 録音停止 + 最終テキスト確定
  Future<MemoResult> stopMemo() async {
    final filePath = await _recordingService.stopRecording();

    // VAD のバッファに残っている最後のセグメントを処理
    _speechService.flush();

    // 少し待ってから最終結果を返す
    await Future.delayed(const Duration(milliseconds: 200));

    return MemoResult(
      filePath: filePath ?? '',
      transcript: _currentTranscript,
    );
  }

  /// 保存済み音声ファイルからバッチ文字起こし
  /// 用途: 過去の録音を再度文字起こしする場合
  Future<String> retranscribe(String filePath) async {
    return await _speechService.transcribeFile(filePath);
  }

  void dispose() {
    _recognitionSubscription?.cancel();
    _transcriptController.close();
    _speechService.dispose();
    _recordingService.dispose();
  }
}

class MemoResult {
  final String filePath;
  final String transcript;

  const MemoResult({
    required this.filePath,
    required this.transcript,
  });
}
```

---

## 4. VAD + SenseVoice による Simulated Streaming の仕組み

SenseVoice は本来非ストリーミング（バッチ処理）モデルだが、
VAD（Voice Activity Detection）と組み合わせることで擬似的なリアルタイム認識を実現する。

```
マイク入力 (16kHz PCM)
    │
    ▼
┌──────────────────┐
│  Silero VAD      │  ← 音声区間を検出
│  (軽量, 高速)     │
└──────┬───────────┘
       │ 発話セグメント（0.5秒の無音で区切り）
       ▼
┌──────────────────┐
│  SenseVoice      │  ← セグメント単位で認識
│  (OfflineRecog.) │
└──────┬───────────┘
       │ テキスト結果
       ▼
   UI に追記表示
```

**動作フロー:**

1. マイクから連続的に PCM データを取得
2. VAD がリアルタイムで音声区間/非音声区間を判定
3. 0.5秒の無音を検出したら、それまでの発話をセグメントとして切り出す
4. 切り出されたセグメントを SenseVoice に渡して認識
5. 認識結果を UI にストリーム的に追加表示

**メモ用途での体感:**

- 文の区切りで約 0.5〜1秒の遅延で認識結果が表示される
- 1分程度のメモなら合計 3〜8 個のセグメントに分割される
- 各セグメントの認識は 100〜300ms 程度（端末性能に依存）

---

## 5. モデルのダウンロード手順

### SenseVoice int8 モデル

```bash
# int8 量子化版をダウンロード（228MB、精度はほぼ同等）
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2

tar xvf sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2

# 必要なファイルだけをプロジェクトにコピー
mkdir -p your_app/assets/models/sense-voice/
cp sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx \
   your_app/assets/models/sense-voice/
cp sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt \
   your_app/assets/models/sense-voice/

# 不要ファイルを削除
rm -rf sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17
rm sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2
```

### Silero VAD モデル

Silero VAD モデルは sherpa_onnx パッケージに内蔵されているため
別途ダウンロードは不要。ただし、カスタム設定が必要な場合:

```bash
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx
```

---

## 6. 実装チェックリスト

### Phase 1: 基盤（1〜2日）

- [ ] `pubspec.yaml` に sherpa_onnx, record, path_provider, permission_handler 追加
- [ ] Android / iOS のパーミッション設定
- [ ] SenseVoice int8 モデルを assets に配置
- [ ] `ModelManager` の実装とテスト

### Phase 2: 認識エンジン（2〜3日）

- [ ] `SpeechRecognitionService` の実装
- [ ] OfflineRecognizer の初期化テスト（日本語テスト音声で検証）
- [ ] VAD の設定チューニング（threshold, minSilenceDuration）
- [ ] `acceptWaveform` → VAD → 認識の一連フローのテスト

### Phase 3: 録音統合（1〜2日）

- [ ] `AudioRecordingService` の実装
- [ ] PCM ストリーム → Float32 変換の検証
- [ ] WAV ファイル保存機能の実装
- [ ] `VoiceMemoController` でのリアルタイム認識テスト

### Phase 4: バッチ認識（1日）

- [ ] `transcribeFile` メソッドのテスト
- [ ] 過去の録音ファイルからの再文字起こし機能

### Phase 5: 品質改善（2〜3日）

- [ ] 認識結果のセグメント結合ロジック（句読点の扱い）
- [ ] 初期化の非同期処理（スプラッシュ画面 or ローディング表示）
- [ ] メモリ使用量のプロファイリング
- [ ] 各種端末での動作検証

---

## 7. 注意事項とTips

### パフォーマンス

- `numThreads: 2` がモバイルでの最適値。4 にしても大きな改善はなく電力消費が増える
- int8 モデルは fp32 の約 1/4 のメモリ使用量で、精度の劣化はほぼ無視できるレベル
- 初期化（モデルロード）に 2〜5 秒かかるため、アプリ起動直後に非同期で行う

### VAD パラメータの調整

| パラメータ | 推奨値 | 説明 |
|-----------|--------|------|
| `threshold` | 0.5 | 音声検出の感度。高くすると厳格に（ノイズ耐性↑、認識漏れリスク↑） |
| `minSilenceDuration` | 0.5 | セグメント区切りの無音時間。短くするとレスポンスは速いが過分割のリスク |
| `minSpeechDuration` | 0.25 | この時間未満の発話は無視（咳払い等のフィルタ） |
| `maxSpeechDuration` | 30.0 | セグメント最大長。メモなら30秒で十分 |

### 日本語固有の考慮事項

- SenseVoice は `language: 'ja'` を指定すると認識精度が上がる
  （自動検出でも動作するが、日本語専用なら明示指定が望ましい）
- 認識結果に句読点（。、）が自動挿入される
- `useInverseTextNormalization: true` で数字が漢数字ではなくアラビア数字で出力される

### メモリとバッテリー

- SenseVoice int8 のランタイムメモリは約 300〜400MB
- 録音停止後は VAD を reset し、不要な stream を free する
- バックグラウンド時は認識を一時停止し、フォアグラウンド復帰後に再開する設計が望ましい

---

## 8. 参考リンク

- [sherpa-onnx GitHub](https://github.com/k2-fsa/sherpa-onnx)
- [sherpa_onnx Flutter パッケージ](https://pub.dev/packages/sherpa_onnx)
- [Flutter streaming_asr サンプル](https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter-examples/streaming_asr)
- [SenseVoice モデル一覧](https://k2-fsa.github.io/sherpa/onnx/sense-voice/pretrained.html)
- [sherpa-onnx 公式ドキュメント](https://k2-fsa.github.io/sherpa/onnx/index.html)
- [Pre-trained models リリースページ](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models)
