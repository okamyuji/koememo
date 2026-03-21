# koememo（こえメモ）

ボイスメモアプリ。録音 → sherpa_onnx でオンデバイス文字起こし → メモとして保存・閲覧。完全オフライン動作。

## 機能

- 音声録音 + リアルタイム文字起こし（SenseVoice int8 モデル）
- 生体認証によるデータ保護（Face ID / 指紋）
- 録音中は認証スキップ、バックグラウンド・スリープ中も録音継続
- メモ一覧（日時順・テキスト検索・フリータグ分類）
- メモ詳細表示・文字起こしテキスト編集・削除
- 音声再生（再生・一時停止・シークバー）
- テキスト共有（OS Share Sheet）
- テーマ切替（ライト/ダーク/システム追随）
- 音声ファイルのみ削除（テキストデータは保持）

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フレームワーク | Flutter 3.41.5 (fvm) / Dart ^3.11.0 |
| 状態管理 | Riverpod 3系 (flutter_riverpod + riverpod_generator) |
| ルーティング | GoRouter |
| ローカルDB | drift (SQLite) |
| 音声認識 | sherpa_onnx (SenseVoice int8 + Silero VAD) |
| 録音 | record |
| 音声再生 | just_audio |
| 生体認証 | local_auth |
| 共有 | share_plus |
| モデル | freezed + json_serializable |

## セットアップ

### 前提条件

- [fvm](https://fvm.app/) がインストール済みであること
- Flutter / Dart コマンドは **全て** `fvm flutter` / `fvm dart` 経由で実行すること

### 手順

```bash
fvm install                          # Flutter SDK をインストール
fvm flutter pub get                  # 依存パッケージ取得
fvm dart run build_runner build      # コード生成 (riverpod, drift, freezed)
```

### モデルファイル

音声認識に必要なモデルファイル（.gitignore 対象）を `assets/models/sense-voice/` に配置:

| ファイル | サイズ | 説明 |
|---------|--------|------|
| model.int8.onnx | 228MB | SenseVoice 多言語ASRモデル（int8量子化） |
| tokens.txt | 309KB | トークン辞書 |
| silero_vad.onnx | 629KB | Silero VAD モデル |

ダウンロード元: [sherpa-onnx SenseVoice releases](https://github.com/k2-fsa/sherpa-onnx/releases)

## コマンド

```bash
fvm flutter run                              # 実行
fvm flutter test                             # テスト（47件）
fvm dart run build_runner build              # コード生成
fvm flutter build ios --release              # iOS リリースビルド
fvm flutter build apk --release              # Android リリースビルド（APK）
```

### 品質ゲート

```bash
fvm flutter analyze                          # warning/error ゼロ
fvm dart format --set-exit-if-changed .      # フォーマット差分ゼロ
fvm flutter test                             # 全テスト Pass
fvm flutter build ios --no-codesign          # iOS ビルド成功
fvm flutter build apk                        # Android ビルド成功
```

## プロジェクト構成

```text
lib/
├── main.dart                          # エントリポイント（sherpa_onnx initBindings）
├── app.dart                           # MaterialApp.router + 認証ライフサイクル管理
├── core/
│   ├── constants.dart                 # アプリ定数（モデルパス、サンプルレート等）
│   ├── theme.dart                     # Material 3 テーマ（ブルー系）
│   ├── router.dart                    # GoRouter + AuthState / RecordingActive providers
│   ├── auth_lifecycle.dart            # State パターンによる認証ライフサイクル管理
│   └── utils/
│       └── pcm_converter.dart         # Int16 PCM → Float32 変換
├── services/
│   ├── speech_recognition_service.dart  # sherpa_onnx ラッパー（VAD + SenseVoice）
│   ├── audio_recording_service.dart     # 録音 + WAV 書き込み
│   ├── audio_playback_service.dart      # just_audio ラッパー
│   ├── model_manager.dart               # モデル assets → Documents コピー
│   ├── auth_service.dart                # local_auth ラッパー
│   ├── share_service.dart               # share_plus ラッパー
│   └── database_service.dart            # drift DB 初期化
├── features/
│   ├── auth/
│   │   └── auth_screen.dart
│   ├── recording/
│   │   ├── recording_screen.dart
│   │   ├── recording_controller.dart
│   │   └── widgets/ (waveform_indicator, live_transcript_view)
│   ├── memo_list/
│   │   ├── memo_list_screen.dart
│   │   ├── memo_list_controller.dart
│   │   └── widgets/ (memo_card, search_bar, tag_filter_chips)
│   ├── memo_detail/
│   │   ├── memo_detail_screen.dart
│   │   ├── memo_detail_controller.dart
│   │   └── widgets/ (audio_player_bar, tag_editor)
│   ├── memo_edit/
│   │   ├── memo_edit_screen.dart
│   │   └── memo_edit_controller.dart
│   └── settings/
│       ├── settings_screen.dart
│       └── settings_controller.dart
├── models/
│   ├── recording_state.dart             # idle / initializing / recording / processing
│   ├── playback_state.dart
│   ├── memo_result.dart
│   └── transcription_result.dart
└── database/
    ├── app_database.dart                # Memos, Tags, MemoTags テーブル定義
    └── daos/
        ├── memo_dao.dart
        └── tag_dao.dart

assets/models/sense-voice/               # モデルファイル（.gitignore対象）
```

## ドキュメント

- 設計文書: `docs/2026-03-21-koememo-design.md`
- 実装計画: `docs/plans/2026-03-21-koememo-implementation.md`
- sherpa_onnx ガイド: `sherpa-onnx-flutter-guide.md`

## 注意事項

- モデルファイル（228MB）は assets に含まれるが、初回起動時に `ModelManager` が Documents ディレクトリにコピーする設計
- `sherpa.initBindings()` を `main.dart` で呼ぶ必要あり（sherpa_onnx 初期化）
- PCM データは Int16 → Float32 変換が必要（バイトアライメントに注意）
- Android は `FlutterFragmentActivity` が必要（local_auth の生体認証ダイアログ）
- iOS: Info.plist に `NSMicrophoneUsageDescription` + `NSFaceIDUsageDescription` + `UIBackgroundModes: audio`
- 音声ファイルパスは Documents からの相対パスで DB に保存
