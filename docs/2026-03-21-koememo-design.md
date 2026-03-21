# koememo 設計文書

## IMPORTANT: 品質ゲート

**以下が全て Pass しないと実装完了とみなさない。全コマンドは fvm 経由で実行すること。**

```bash
fvm flutter analyze                          # static analyze: warning/error ゼロ
fvm dart format --set-exit-if-changed .      # formatter: 差分ゼロ
fvm flutter test                             # 全テスト Pass
fvm flutter build ios --no-codesign          # iOS ビルド成功
fvm flutter build apk                        # Android ビルド成功
```

## IMPORTANT: fvm によるバージョン固定

- Flutter SDK のバージョンは fvm で固定すること
- `flutter`, `dart` コマンドは全て `fvm flutter`, `fvm dart` 経由で実行すること
- `dart analyze`, `dart format`, `flutter test`, `flutter build` など linter/formatter/test/build も全て fvm 経由
- CI 環境でも fvm を使用すること

---

## 1. 概要

ボイスメモアプリ。録音 → sherpa_onnx でオンデバイス文字起こし → メモとして保存・閲覧。完全オフライン動作。iOS / Android 対応。

### 必須要件

- 生体認証によるデータ保護（アプリ起動時 + バックグラウンド復帰時）
- 録音中は認証スキップ（バックグラウンド・スリープ中も録音継続）
- 完全オフライン動作
- メモの保存・文字起こしテキスト編集・削除
- テキストの Share 機能（OS Share Sheet）
- テーマ切替（ライト/ダーク/システム追随、設定で選択可能）
- 日時順 + テキスト検索 + フリータグ分類
- 音声再生（再生・一時停止・シークバー）
- 画面にはわかりやすい日本語ラベル
- ユニットテスト必須

---

## 2. 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フレームワーク | Flutter (fvm でバージョン固定) |
| 状態管理 | Riverpod 3系 (flutter_riverpod + riverpod_generator) |
| ルーティング | GoRouter |
| ローカルDB | drift (SQLite ベース) |
| 音声認識 | sherpa_onnx (SenseVoice int8) |
| 録音 | record パッケージ |
| 音声再生 | just_audio |
| 生体認証 | local_auth |
| 共有 | share_plus |
| テーマ永続化 | shared_preferences |
| モデル | freezed + json_serializable |

### 依存パッケージ一覧

**dependencies:**

| パッケージ | 用途 |
|-----------|------|
| flutter_riverpod | 状態管理 (v3系) |
| riverpod_annotation | @riverpod アノテーション |
| go_router | ルーティング・認証ガード |
| drift | ローカルDB |
| drift_flutter | drift Flutter 統合 |
| sherpa_onnx | 音声認識 |
| record | マイク録音 |
| just_audio | 音声再生 |
| local_auth | 生体認証 |
| share_plus | OS Share Sheet |
| path_provider | ファイルパス管理 |
| shared_preferences | テーマ設定永続化 |
| freezed_annotation | immutable モデル |
| json_annotation | JSON シリアライズ |
| flutter_local_notifications | Android Foreground Service 通知 |

**dev_dependencies:**

| パッケージ | 用途 |
|-----------|------|
| riverpod_generator | Riverpod コード生成 |
| build_runner | コード生成実行 |
| drift_dev | drift コード生成 |
| freezed | freezed コード生成 |
| json_serializable | JSON コード生成 |
| flutter_test | テストフレームワーク |
| flutter_lints | lint ルール |

---

## 3. 画面構成とナビゲーション

### 画面一覧

| 画面 | パス | 日本語ラベル | 役割 |
|------|------|-------------|------|
| AuthScreen | `/auth` | - | 生体認証（起動時・復帰時） |
| MemoListScreen | `/` | 「メモ一覧」 | メモの一覧表示・検索・タグフィルタ |
| RecordingScreen | `/recording` | 「録音」 | 録音 + リアルタイム文字起こし |
| MemoDetailScreen | `/memo/:id` | 「メモ詳細」 | 再生・テキスト表示・Share・タグ管理・音声削除 |
| MemoEditScreen | `/memo/:id/edit` | 「メモ編集」 | 文字起こしテキストの編集 |
| SettingsScreen | `/settings` | 「設定」 | テーマ切替（ライト/ダーク/システム） |

### 認証フロー

- GoRouter `redirect` で認証状態判定 → 未認証なら `/auth` にリダイレクト
- `WidgetsBindingObserver.didChangeAppLifecycleState` でバックグラウンド復帰検知
- **録音中は認証スキップ**: GoRouter redirect 内で `RecordingController` の状態を参照し、録音中なら認証をバイパス（AuthState に録音フラグを持たせず、状態の二重管理を避ける）
- 録音停止後の復帰時は通常通り認証要求

### バックグラウンド録音

- iOS: `UIBackgroundModes: audio` + AVAudioSession `.playAndRecord`
- Android: Foreground Service + 通知表示 + WakeLock
- スリープ中も録音継続

---

## 4. データモデル（drift）

```dart
// === memos テーブル ===
class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get transcript => text().withDefault(const Constant(''))();
  TextColumn get audioFilePath => text().nullable()();  // 音声削除時は null
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// === tags テーブル ===
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50).unique()();
  DateTimeColumn get createdAt => dateTime()();
}

// === memo_tags 中間テーブル (多対多) ===
class MemoTags extends Table {
  IntColumn get memoId => integer().references(Memos, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {memoId, tagId};
}
```

**設計判断:**
- `title` はデフォルトで「2026/03/21 14:30 のメモ」のように自動生成。後から編集可能
- `audioFilePath` は Documents ディレクトリからの相対パスで保存
- 音声ファイルのみ削除可能（テキストデータは残る）。`audioFilePath` を null にして音声ファイルを削除
- メモ全体の削除時は CASCADE で `memo_tags` も削除。音声ファイルもアプリ側で削除処理
- タグは `unique` 制約で重複防止

---

## 5. サービス層

```text
lib/services/
├── speech_recognition_service.dart   # sherpa_onnx ラッパー
├── audio_recording_service.dart      # 録音 + バックグラウンド継続
├── audio_playback_service.dart       # 音声再生 (just_audio)
├── model_manager.dart                # onnx モデル assets → FS コピー
├── auth_service.dart                 # 生体認証 (local_auth)
├── share_service.dart                # テキスト共有 (share_plus)
└── database_service.dart             # drift DB 初期化・提供
```

| サービス | パッケージ | 責務 |
|---------|-----------|------|
| SpeechRecognitionService | sherpa_onnx | VAD + SenseVoice で文字起こし。`sherpa-onnx-flutter-guide.md` 準拠 |
| AudioRecordingService | record | 録音開始/停止、PCM ストリーム提供、WAV ファイル書き込み。バックグラウンド・スリープ継続 |
| AudioPlaybackService | just_audio | 再生/一時停止/シーク |
| ModelManager | path_provider | assets → Documents コピー（model.int8.onnx, tokens.txt, silero_vad.onnx）。初回のみ |
| AuthService | local_auth | 生体認証実行・利用可否チェック・認証状態管理 |
| ShareService | share_plus | OS Share Sheet 経由テキスト共有 |
| DatabaseService | drift | DB 接続管理 |

**設計原則:**
- 全サービスは Riverpod Provider として提供
- feature から直接パッケージを呼ばない
- テスト時は Provider override でモック差し替え

---

## 6. 状態管理（Riverpod 3 Provider 構成）

```dart
// === core providers ===
@riverpod AppDatabase database(Ref ref)
@riverpod AuthService authService(Ref ref)

// === 認証状態 ===
@riverpod
class AuthState extends _$AuthState {
  bool build() => false;  // 認証済みかどうか
  void authenticate() => state = true;
  void lock() => state = false;
  // 録音中の認証スキップ判定は GoRouter redirect 内で
  // RecordingController の状態を参照して行う（状態の二重管理を避ける）
}

// === メモ一覧 ===
@riverpod Future<List<Memo>> memoList(Ref ref, {String? searchQuery, int? tagId})
@riverpod Future<List<Tag>> tagList(Ref ref)

// === 録音 ===
@riverpod
class RecordingController extends _$RecordingController {
  // build() → RecordingState (idle / recording / processing)
  Future<void> startRecording();
  Future<MemoResult> stopRecording();
  Stream<String> get liveTranscript;
}

// === メモ詳細 ===
@riverpod Future<Memo> memoDetail(Ref ref, int memoId)
@riverpod Future<List<Tag>> memoTags(Ref ref, int memoId)

// === メモ編集 ===
@riverpod
class MemoEditor extends _$MemoEditor {
  Future<void> updateTranscript(int memoId, String text);
  Future<void> deleteMemo(int memoId);          // メモ全体削除（音声+テキスト+タグ）
  Future<void> deleteAudioFile(int memoId);      // 音声ファイルのみ削除（テキストは残る）
  Future<void> addTag(int memoId, String tagName);
  Future<void> removeTag(int memoId, int tagId);
}

// === 音声再生 ===
@riverpod
class AudioPlayer extends _$AudioPlayer {
  // build() → PlaybackState (stopped / playing / paused)
  Future<void> play(String filePath);
  void pause();
  void seek(Duration position);
  Stream<Duration> get position;
  Stream<Duration> get duration;
}

// === 設定 ===
@riverpod
class ThemeSetting extends _$ThemeSetting {
  ThemeMode build() => ThemeMode.system;
  void setThemeMode(ThemeMode mode);
}
```

---

## 7. アーキテクチャ全体図

```text
┌─────────────────────────────────────────────┐
│  UI Layer (features/)                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ recording│ │ memo_list│ │ memo_detail  │ │
│  │ _screen  │ │ _screen  │ │ _screen/edit │ │
│  └────┬─────┘ └────┬─────┘ └──────┬───────┘ │
│       │            │              │          │
├───────┴────────────┴──────────────┴──────────┤
│  State Layer (Riverpod 3 Providers)          │
│  RecordingController / MemoEditor /          │
│  AudioPlayer / AuthState / ThemeSetting      │
├──────────────────────────────────────────────┤
│  Service Layer (services/)                   │
│  speech_recognition / audio_recording /      │
│  audio_playback / auth / share / database    │
├──────────────────────────────────────────────┤
│  Data Layer                                  │
│  drift (SQLite) / File System (音声ファイル) │
└──────────────────────────────────────────────┘
```

**データフロー（録音→保存）:**

1. RecordingScreen → FABタップ → `RecordingController.startRecording()`
2. AudioRecordingService がマイク開始（バックグラウンド継続）
3. PCM ストリーム → Int16→Float32変換 → SpeechRecognitionService
4. VAD セグメント検出 → SenseVoice 認識 → リアルタイムテキスト表示
5. 停止 → flush → Memo を drift に保存 + 音声ファイル保持

---

## 8. テスト戦略

| レイヤー | テスト対象 | テスト方法 |
|---------|-----------|-----------|
| services/ | SpeechRecognitionService | PCM → テキスト変換のユニットテスト（モデルのモック） |
| services/ | AudioRecordingService | 録音状態遷移のユニットテスト |
| services/ | AuthService | 認証フロー（成功/失敗/未対応端末）のユニットテスト |
| services/ | DatabaseService | drift の in-memory DB で CRUD テスト |
| models/ | Memo, Tag, MemoTag | drift 生成コードの整合性テスト |
| features/ | RecordingController | 録音→文字起こし→保存フローのユニットテスト |
| features/ | MemoEditor | 編集・削除・タグ操作のユニットテスト |
| features/ | AudioPlayer | 再生状態遷移のユニットテスト |
| features/ | AuthState | 認証状態・録音中スキップ判定のユニットテスト |
| features/ | ThemeSetting | テーマ切替永続化のユニットテスト |

**テスト方針:**
- サービス層は Riverpod Provider override でモック差し替え
- drift は `NativeDatabase.memory()` でインメモリテスト
- Widget テストはスコープ外（将来追加可能）

---

## 9. ディレクトリ構成

```text
lib/
├── main.dart
├── app.dart                           # MaterialApp + GoRouter + テーマ設定
├── core/
│   ├── constants.dart
│   ├── theme.dart                     # Material 3 テーマ (ブルー系, ライト/ダーク)
│   ├── router.dart                    # GoRouter 定義 + 認証ガード
│   └── utils/
│       └── pcm_converter.dart
├── services/
│   ├── speech_recognition_service.dart
│   ├── audio_recording_service.dart
│   ├── audio_playback_service.dart
│   ├── model_manager.dart
│   ├── auth_service.dart
│   ├── share_service.dart
│   └── database_service.dart
├── features/
│   ├── auth/
│   │   └── auth_screen.dart
│   ├── recording/
│   │   ├── recording_screen.dart
│   │   ├── recording_controller.dart
│   │   └── widgets/
│   │       ├── waveform_indicator.dart
│   │       └── live_transcript_view.dart
│   ├── memo_list/
│   │   ├── memo_list_screen.dart
│   │   ├── memo_list_controller.dart
│   │   └── widgets/
│   │       ├── memo_card.dart
│   │       ├── search_bar.dart
│   │       └── tag_filter_chips.dart
│   ├── memo_detail/
│   │   ├── memo_detail_screen.dart
│   │   ├── memo_detail_controller.dart
│   │   └── widgets/
│   │       ├── audio_player_bar.dart
│   │       └── tag_editor.dart
│   ├── memo_edit/
│   │   ├── memo_edit_screen.dart
│   │   └── memo_edit_controller.dart
│   └── settings/
│       ├── settings_screen.dart
│       └── settings_controller.dart
├── models/
│   ├── recording_state.dart       # 録音状態 (freezed)
│   ├── playback_state.dart        # 再生状態 (freezed)
│   ├── memo_result.dart           # 録音結果 (freezed)
│   └── transcription_result.dart  # 認識結果 (freezed)
└── database/
    ├── app_database.dart              # drift DB 定義
    └── daos/
        ├── memo_dao.dart
        └── tag_dao.dart
```
