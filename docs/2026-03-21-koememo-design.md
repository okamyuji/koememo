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
| riverpod_generator ^4.0.3 | Riverpod コード生成 |
| build_runner ^2.4.14 | コード生成実行 |
| drift_dev ^2.31.0 | drift コード生成 |
| freezed ^3.2.5 | freezed コード生成 |
| json_serializable ^6.9.4 | JSON コード生成 |
| flutter_test | テストフレームワーク |
| flutter_lints ^6.0.0 | lint ルール |
| riverpod_lint ^3.0.0 | Riverpod lint ルール |
| mockito ^5.4.5 | テスト用モック生成 |

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
- 認証ライフサイクルは **GoF State パターン**で管理（`lib/core/auth_lifecycle.dart`）
  - `UnauthenticatedState` → `AuthenticatedForegroundState` → `AuthenticatedBackgroundState`
  - `paused` のみバックグラウンド遷移（`inactive` は Face ID ダイアログ等のため無視）
- **録音中は認証スキップ**: `RecordingActive` boolean provider を router と auth_lifecycle の両方から参照
- GoRouter provider は手書き `Provider<GoRouter>` を使用（`@Riverpod` だと起動時クラッシュ）
- `app.dart` の `ref.listen` で authState/recordingActive 変更時に `goRouter.refresh()` で redirect 再評価
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

**注意:** 一部の provider は drift 型との互換性やパフォーマンス上の理由から手書き。

```dart
// === core providers ===
// database: 手書き Provider（drift_flutter の driftDatabase() 使用）
final appDatabaseProvider = Provider<AppDatabase>(...);
// auth: 手書き Provider
final authServiceProvider = Provider<AuthService>(...);

// === 認証・録音状態 (@Riverpod, keepAlive: true) ===
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  bool build() => false;
  void authenticate() => state = true;
  void lock() => state = false;
}

@Riverpod(keepAlive: true)
class RecordingActive extends _$RecordingActive {
  bool build() => false;
  void start() => state = true;
  void stop() => state = false;
}

// === GoRouter（手書き Provider、@Riverpod ではない）===
final routerProvider = Provider<GoRouter>((ref) {
  // ref.read で authState/recordingActive を参照
  // app.dart の ref.listen + goRouter.refresh() で redirect 再評価
});

// === メモ一覧（手書き FutureProvider.family）===
// drift 生成型が riverpod_generator と非互換のため手書き
final memoListProvider = FutureProvider.family<List<Memo>, ({String? searchQuery, int? tagId})>(...);
final tagListProvider = FutureProvider<List<Tag>>(...);

// === 録音 (@riverpod) ===
@riverpod
class RecordingController extends _$RecordingController {
  // build() → RecordingState (idle / initializing / recording / processing)
  Future<void> startRecording();  // 初期化 → 録音開始の順
  Future<MemoResult?> stopRecording();
  void cancelRecording();
}
// リアルタイム文字起こし（手書き NotifierProvider）
final liveTranscriptProvider = NotifierProvider<LiveTranscriptNotifier, String>(...);

// === メモ詳細（手書き FutureProvider.family）===
final memoDetailProvider = FutureProvider.family<Memo, int>(...);
final memoTagsProvider = FutureProvider.family<List<Tag>, int>(...);

// === メモ編集 (@riverpod) ===
@riverpod
class MemoEditor extends _$MemoEditor {
  Future<void> updateTranscript(int memoId, String text);
  Future<void> deleteMemo(int memoId);
  Future<void> deleteAudioFile(int memoId);
  Future<void> addTag(int memoId, String tagName);
  Future<void> removeTag(int memoId, int tagId);
}

// === 設定 (@riverpod) ===
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
2. 状態を `initializing` に → UI で「音声認識モデルを準備中...」表示
3. マイク権限チェック → SpeechRecognitionService 初期化（モデルロード含む）
4. AudioRecordingService がマイク開始 → 状態を `recording` に → `RecordingActive.start()`
5. PCM ストリーム（Uint8List）→ Int16→Float32変換（アライメント考慮）→ SpeechRecognitionService
6. VAD セグメント検出 → SenseVoice オフライン認識 → `liveTranscriptProvider` でリアルタイム表示
7. 停止 → flush → Memo を drift に保存（相対パス）+ 音声 WAV ファイル保持
8. `memoListProvider` / `tagListProvider` を invalidate して一覧更新

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
- AuthService は mockito でモック生成
- Widget テストはスコープ外（将来追加可能）
- 現在 47 テスト Pass

---

## 9. ディレクトリ構成

```text
lib/
├── main.dart                          # エントリポイント（sherpa.initBindings()）
├── app.dart                           # MaterialApp.router + 認証ライフサイクル管理
├── core/
│   ├── constants.dart                 # モデルパス、サンプルレート等
│   ├── theme.dart                     # Material 3 テーマ (ブルー系, ライト/ダーク)
│   ├── router.dart                    # GoRouter + AuthState / RecordingActive providers
│   ├── auth_lifecycle.dart            # State パターン認証ライフサイクル管理
│   └── utils/
│       └── pcm_converter.dart         # Int16 PCM → Float32 変換（アライメント対応）
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
│   ├── recording_state.dart       # 録音状態 (freezed): idle/initializing/recording/processing
│   ├── playback_state.dart        # 再生状態 (freezed)
│   ├── memo_result.dart           # 録音結果 (freezed)
│   └── transcription_result.dart  # 認識結果 (freezed)
└── database/
    ├── app_database.dart              # drift DB 定義
    └── daos/
        ├── memo_dao.dart
        └── tag_dao.dart
```
