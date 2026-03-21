# koememo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** オンデバイス音声認識によるボイスメモアプリの実装（生体認証・バックグラウンド録音・オフライン完全対応）

**Architecture:** Feature-first 構成 + Riverpod 3 + GoRouter。サービス層が外部パッケージをラップし、Provider 経由で feature に注入。drift (SQLite) でローカル永続化。

**Tech Stack:** Flutter 3.41.5 (fvm固定) / Riverpod 3 / GoRouter / drift / sherpa_onnx / record / just_audio / local_auth

**設計文書:** `docs/2026-03-21-koememo-design.md`
**sherpa_onnx ガイド:** `sherpa-onnx-flutter-guide.md`

---

## IMPORTANT: 全コマンドは fvm 経由で実行すること

```bash
fvm flutter ...    # flutter コマンド
fvm dart ...       # dart コマンド
```

## IMPORTANT: 品質ゲート（各タスク完了時に実行）

```bash
fvm flutter analyze                          # warning/error ゼロ
fvm dart format --set-exit-if-changed .      # 差分ゼロ
fvm flutter test                             # 全テスト Pass
```

## IMPORTANT: 最終品質ゲート（全タスク完了後）

```bash
fvm flutter analyze
fvm dart format --set-exit-if-changed .
fvm flutter test
fvm flutter build ios --no-codesign
fvm flutter build apk
```

---

## File Map

### 新規作成ファイル一覧

**Core:**
- `lib/main.dart` — エントリポイント（既存を書き換え）
- `lib/app.dart` — MaterialApp + ProviderScope + テーマ
- `lib/core/constants.dart` — アプリ定数
- `lib/core/theme.dart` — Material 3 テーマ（ブルー系、ライト/ダーク）
- `lib/core/router.dart` — GoRouter 定義 + 認証リダイレクト
- `lib/core/utils/pcm_converter.dart` — Int16 PCM → Float32 変換

**Database:**
- `lib/database/app_database.dart` — drift テーブル定義 + DB クラス
- `lib/database/daos/memo_dao.dart` — Memo CRUD + 検索
- `lib/database/daos/tag_dao.dart` — Tag CRUD + MemoTag 中間テーブル操作

**Services:**
- `lib/services/auth_service.dart` — local_auth ラッパー
- `lib/services/model_manager.dart` — onnx モデル assets → FS コピー
- `lib/services/speech_recognition_service.dart` — sherpa_onnx (VAD + SenseVoice)
- `lib/services/audio_recording_service.dart` — 録音 + PCM ストリーム + WAV 保存
- `lib/services/audio_playback_service.dart` — just_audio ラッパー
- `lib/services/share_service.dart` — share_plus ラッパー
- `lib/services/database_service.dart` — drift DB Provider

**Features:**
- `lib/features/auth/auth_screen.dart` — 生体認証画面
- `lib/features/recording/recording_screen.dart` — 録音画面
- `lib/features/recording/recording_controller.dart` — 録音 + 文字起こし Notifier
- `lib/features/recording/widgets/waveform_indicator.dart` — 波形表示
- `lib/features/recording/widgets/live_transcript_view.dart` — リアルタイムテキスト
- `lib/features/memo_list/memo_list_screen.dart` — メモ一覧画面
- `lib/features/memo_list/memo_list_controller.dart` — 一覧 + 検索 + タグフィルタ
- `lib/features/memo_list/widgets/memo_card.dart` — メモカード
- `lib/features/memo_list/widgets/search_bar.dart` — 検索バー
- `lib/features/memo_list/widgets/tag_filter_chips.dart` — タグフィルタチップ
- `lib/features/memo_detail/memo_detail_screen.dart` — メモ詳細画面
- `lib/features/memo_detail/memo_detail_controller.dart` — 詳細 Notifier
- `lib/features/memo_detail/widgets/audio_player_bar.dart` — 再生バー
- `lib/features/memo_detail/widgets/tag_editor.dart` — タグ編集
- `lib/features/memo_edit/memo_edit_screen.dart` — テキスト編集画面
- `lib/features/memo_edit/memo_edit_controller.dart` — 編集 Notifier
- `lib/features/settings/settings_screen.dart` — 設定画面
- `lib/features/settings/settings_controller.dart` — テーマ設定 Notifier

**Models:**
- `lib/models/recording_state.dart` — 録音状態 enum (freezed)
- `lib/models/playback_state.dart` — 再生状態 (freezed)
- `lib/models/memo_result.dart` — 録音結果 (freezed)
- `lib/models/transcription_result.dart` — 認識結果（テキスト + isFinal + 検出言語）

注: `Memo` / `Tag` / `MemoTag` 型は drift が `lib/database/app_database.g.dart` に自動生成する。`lib/models/memo.dart` は不要（drift 生成型を直接使用）。

**Tests:**
- `test/database/memo_dao_test.dart`
- `test/database/tag_dao_test.dart`
- `test/services/auth_service_test.dart`
- `test/services/audio_recording_service_test.dart`
- `test/services/audio_playback_service_test.dart`
- `test/services/speech_recognition_service_test.dart`
- `test/features/recording/recording_controller_test.dart`
- `test/features/memo_list/memo_list_controller_test.dart`
- `test/features/memo_detail/memo_detail_controller_test.dart`
- `test/features/memo_edit/memo_edit_controller_test.dart`
- `test/features/settings/settings_controller_test.dart`
- `test/features/auth/auth_state_test.dart`
- `test/features/memo_detail/audio_player_test.dart`
- `test/core/utils/pcm_converter_test.dart`

**Platform config:**
- `android/app/src/main/AndroidManifest.xml` — 修正（permissions, foreground service）
- `android/app/build.gradle` — 修正（minSdk, aaptOptions）
- `ios/Runner/Info.plist` — 修正（NSMicrophoneUsageDescription, UIBackgroundModes）
- `ios/Podfile` — 修正（platform :ios, '13.0'）

---

## Task 1: プロジェクト基盤セットアップ（fvm + 依存パッケージ）

**Files:**
- Modify: `pubspec.yaml`
- Create: `.fvmrc`
- Modify: `.gitignore`

- [ ] **Step 1: fvm でFlutter バージョンを固定**

```bash
cd /Users/yujiokamoto/devs/flutter_app/koememo
fvm use 3.41.5
```

これで `.fvmrc` が作成される。

- [ ] **Step 2: .gitignore に fvm と生成ファイルを追加**

`.gitignore` に以下を追記:

```
.fvm/
*.g.dart
*.freezed.dart
.superpowers/
```

- [ ] **Step 3: pubspec.yaml を書き換え**

```yaml
name: koememo
description: "ボイスメモアプリ - オンデバイス文字起こし"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0
  go_router: ^15.1.0
  drift: ^2.25.0
  drift_flutter: ^0.3.0
  sherpa_onnx: ^1.12.0
  record: ^5.2.0
  just_audio: ^0.9.43
  local_auth: ^2.3.0
  share_plus: ^10.1.4
  path_provider: ^2.1.5
  shared_preferences: ^2.3.4
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0
  flutter_local_notifications: ^18.0.1
  path: ^1.9.1
  sqlite3_flutter_libs: ^0.5.31

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  riverpod_generator: ^3.0.0
  build_runner: ^2.4.14
  drift_dev: ^2.25.0
  freezed: ^3.0.0
  json_serializable: ^6.9.4
  riverpod_lint: ^3.0.0
  mockito: ^5.4.5
  build_runner_core: ^8.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/models/sense-voice/
```

- [ ] **Step 4: パッケージ取得**

```bash
fvm flutter pub get
```

Expected: 正常終了、エラーなし

- [ ] **Step 5: 品質ゲート確認**

```bash
fvm flutter analyze
```

Expected: info レベルのみ（既存の main.dart テンプレートの warning は次タスクで解消）

- [ ] **Step 6: コミット**

```bash
git init
git add .fvmrc pubspec.yaml .gitignore
git commit -m "chore: setup fvm 3.41.5 and add dependencies"
```

---

## Task 2: プラットフォーム設定（Android / iOS）

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts` or `build.gradle`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Podfile`

- [ ] **Step 1: Android AndroidManifest.xml を修正**

`<manifest>` 直下に追加:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

`<application>` タグに `android:largeHeap="true"` を追加。

- [ ] **Step 2: Android build.gradle を修正**

`defaultConfig` 内:
```groovy
minSdk = 23  // sherpa_onnx + local_auth の最小要件
```

`android` ブロック内に追加:
```groovy
aaptOptions {
    noCompress 'onnx'
}
```

- [ ] **Step 3: iOS Info.plist を修正**

以下を追加:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>音声メモの録音と文字起こしに使用します</string>
<key>NSFaceIDUsageDescription</key>
<string>アプリのロック解除に使用します</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

- [ ] **Step 4: iOS Podfile を修正**

```ruby
platform :ios, '13.0'
```

`post_install` ブロック内に:
```ruby
config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
```

- [ ] **Step 5: ビルド確認**

```bash
fvm flutter build apk --debug
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: 品質ゲート + コミット**

```bash
fvm flutter analyze
fvm flutter test
git add android/ ios/
git commit -m "chore: configure Android/iOS permissions and platform settings"
```

---

## Task 3: Core 層（テーマ・定数・PCM変換）

**Files:**
- Create: `lib/core/constants.dart`
- Create: `lib/core/theme.dart`
- Create: `lib/core/utils/pcm_converter.dart`
- Create: `test/core/utils/pcm_converter_test.dart`

- [ ] **Step 1: pcm_converter のテストを書く**

```dart
// test/core/utils/pcm_converter_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/core/utils/pcm_converter.dart';

void main() {
  group('PcmConverter', () {
    test('converts Int16 PCM bytes to Float32 samples', () {
      // Int16: 0, 16384 (half max), -32768 (min)
      final bytes = Uint8List.fromList([
        0x00, 0x00, // 0
        0x00, 0x40, // 16384
        0x00, 0x80, // -32768 (little-endian)
      ]);
      final result = PcmConverter.int16BytesToFloat32(bytes);
      expect(result.length, 3);
      expect(result[0], closeTo(0.0, 0.001));
      expect(result[1], closeTo(0.5, 0.001));
      expect(result[2], closeTo(-1.0, 0.001));
    });

    test('returns empty list for empty input', () {
      final result = PcmConverter.int16BytesToFloat32(Uint8List(0));
      expect(result, isEmpty);
    });

    test('all values are in range -1.0 to 1.0', () {
      // Max positive Int16: 32767
      final bytes = Uint8List.fromList([0xFF, 0x7F]);
      final result = PcmConverter.int16BytesToFloat32(bytes);
      expect(result[0], closeTo(1.0, 0.001));
      expect(result[0], lessThanOrEqualTo(1.0));
    });
  });
}
```

- [ ] **Step 2: テスト実行 → 失敗確認**

```bash
fvm flutter test test/core/utils/pcm_converter_test.dart
```

Expected: FAIL（ファイル未作成）

- [ ] **Step 3: pcm_converter を実装**

```dart
// lib/core/utils/pcm_converter.dart
import 'dart:typed_data';

class PcmConverter {
  PcmConverter._();

  /// Int16 PCM バイト列 (little-endian) を Float32 サンプル列に変換。
  /// sherpa_onnx が要求する -1.0〜1.0 の範囲に正規化する。
  static Float32List int16BytesToFloat32(Uint8List bytes) {
    final int16Data = Int16List.view(bytes.buffer, bytes.offsetInBytes,
        bytes.lengthInBytes ~/ 2);
    final float32Data = Float32List(int16Data.length);
    for (var i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    return float32Data;
  }
}
```

- [ ] **Step 4: テスト実行 → Pass 確認**

```bash
fvm flutter test test/core/utils/pcm_converter_test.dart
```

Expected: All tests passed

- [ ] **Step 5: constants.dart を作成**

```dart
// lib/core/constants.dart
class AppConstants {
  AppConstants._();

  static const String appName = 'こえメモ';
  static const int sampleRate = 16000;
  static const int numChannels = 1;
  static const int numThreads = 2;
  static const String modelAssetDir = 'assets/models/sense-voice';
  static const String modelFileName = 'model.int8.onnx';
  static const String tokensFileName = 'tokens.txt';
  static const String vadFileName = 'silero_vad.onnx';
  static const String language = 'ja';
}
```

- [ ] **Step 6: theme.dart を作成**

```dart
// lib/core/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF1565C0); // Blue 800

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
```

- [ ] **Step 7: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/core/ test/core/
git commit -m "feat: add core layer (theme, constants, pcm_converter)"
```

---

## Task 4: Database 層（drift テーブル定義 + DAO）

**Files:**
- Create: `lib/database/app_database.dart`
- Create: `lib/database/daos/memo_dao.dart`
- Create: `lib/database/daos/tag_dao.dart`
- Create: `test/database/memo_dao_test.dart`
- Create: `test/database/tag_dao_test.dart`

- [ ] **Step 1: memo_dao のテストを書く**

```dart
// test/database/memo_dao_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/memo_dao.dart';

void main() {
  late AppDatabase db;
  late MemoDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = MemoDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MemoDao', () {
    test('inserts and retrieves a memo', () async {
      final id = await dao.insertMemo(
        title: 'テストメモ',
        transcript: 'こんにちは',
        audioFilePath: 'memos/test.wav',
        durationMs: 5000,
      );
      expect(id, greaterThan(0));

      final memo = await dao.getMemoById(id);
      expect(memo, isNotNull);
      expect(memo!.title, 'テストメモ');
      expect(memo.transcript, 'こんにちは');
      expect(memo.audioFilePath, 'memos/test.wav');
      expect(memo.durationMs, 5000);
    });

    test('lists memos in descending order by createdAt', () async {
      await dao.insertMemo(title: 'First', transcript: '', audioFilePath: 'a.wav', durationMs: 0);
      await Future.delayed(const Duration(milliseconds: 10));
      await dao.insertMemo(title: 'Second', transcript: '', audioFilePath: 'b.wav', durationMs: 0);

      final memos = await dao.getAllMemos();
      expect(memos.length, 2);
      expect(memos.first.title, 'Second');
    });

    test('searches memos by transcript text', () async {
      await dao.insertMemo(title: 'A', transcript: '今日は天気がいい', audioFilePath: 'a.wav', durationMs: 0);
      await dao.insertMemo(title: 'B', transcript: '明日は雨', audioFilePath: 'b.wav', durationMs: 0);

      final results = await dao.searchMemos('天気');
      expect(results.length, 1);
      expect(results.first.title, 'A');
    });

    test('updates transcript', () async {
      final id = await dao.insertMemo(title: 'T', transcript: 'old', audioFilePath: 'a.wav', durationMs: 0);
      await dao.updateTranscript(id, 'new');
      final memo = await dao.getMemoById(id);
      expect(memo!.transcript, 'new');
    });

    test('deletes audio file path (sets to null)', () async {
      final id = await dao.insertMemo(title: 'T', transcript: 'text', audioFilePath: 'a.wav', durationMs: 1000);
      await dao.deleteAudioFile(id);
      final memo = await dao.getMemoById(id);
      expect(memo!.audioFilePath, isNull);
      expect(memo.transcript, 'text'); // テキストは残る
    });

    test('deletes memo', () async {
      final id = await dao.insertMemo(title: 'T', transcript: '', audioFilePath: 'a.wav', durationMs: 0);
      await dao.deleteMemo(id);
      final memo = await dao.getMemoById(id);
      expect(memo, isNull);
    });
  });
}
```

- [ ] **Step 2: tag_dao のテストを書く**

```dart
// test/database/tag_dao_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/database/app_database.dart';
import 'package:koememo/database/daos/tag_dao.dart';

void main() {
  late AppDatabase db;
  late TagDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = TagDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TagDao', () {
    test('creates and retrieves a tag', () async {
      final id = await dao.createTag('仕事');
      final tags = await dao.getAllTags();
      expect(tags.length, 1);
      expect(tags.first.name, '仕事');
      expect(tags.first.id, id);
    });

    test('prevents duplicate tag names', () async {
      await dao.createTag('仕事');
      expect(() => dao.createTag('仕事'), throwsA(anything));
    });

    test('adds tag to memo and retrieves', () async {
      final memoDao = db.memoDao;
      final memoId = await memoDao.insertMemo(title: 'T', transcript: '', audioFilePath: 'a.wav', durationMs: 0);
      final tagId = await dao.createTag('重要');

      await dao.addTagToMemo(memoId, tagId);
      final tags = await dao.getTagsForMemo(memoId);
      expect(tags.length, 1);
      expect(tags.first.name, '重要');
    });

    test('removes tag from memo', () async {
      final memoDao = db.memoDao;
      final memoId = await memoDao.insertMemo(title: 'T', transcript: '', audioFilePath: 'a.wav', durationMs: 0);
      final tagId = await dao.createTag('重要');
      await dao.addTagToMemo(memoId, tagId);

      await dao.removeTagFromMemo(memoId, tagId);
      final tags = await dao.getTagsForMemo(memoId);
      expect(tags, isEmpty);
    });

    test('gets memos by tag', () async {
      final memoDao = db.memoDao;
      final memoId1 = await memoDao.insertMemo(title: 'A', transcript: '', audioFilePath: 'a.wav', durationMs: 0);
      final memoId2 = await memoDao.insertMemo(title: 'B', transcript: '', audioFilePath: 'b.wav', durationMs: 0);
      final tagId = await dao.createTag('仕事');

      await dao.addTagToMemo(memoId1, tagId);
      // memoId2 にはタグなし

      final memos = await dao.getMemosByTag(tagId);
      expect(memos.length, 1);
      expect(memos.first.title, 'A');
    });

    test('deletes tag', () async {
      final tagId = await dao.createTag('削除予定');
      await dao.deleteTag(tagId);
      final tags = await dao.getAllTags();
      expect(tags, isEmpty);
    });
  });
}
```

- [ ] **Step 3: テスト実行 → 失敗確認**

```bash
fvm flutter test test/database/
```

Expected: FAIL

- [ ] **Step 4: app_database.dart を実装**

```dart
// lib/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'daos/memo_dao.dart';
import 'daos/tag_dao.dart';

part 'app_database.g.dart';

class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get transcript => text().withDefault(const Constant(''))();
  TextColumn get audioFilePath => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50).unique()();
  DateTimeColumn get createdAt => dateTime()();
}

class MemoTags extends Table {
  IntColumn get memoId => integer().references(Memos, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {memoId, tagId};
}

@DriftDatabase(tables: [Memos, Tags, MemoTags], daos: [MemoDao, TagDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  /// 本番用コンストラクタ
  AppDatabase.defaults()
      : super(DriftFlutterDatabase(name: 'koememo.db'));

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 5: memo_dao.dart を実装**

```dart
// lib/database/daos/memo_dao.dart
import 'package:drift/drift.dart';
import '../app_database.dart';

part 'memo_dao.g.dart';

@DriftAccessor(tables: [Memos])
class MemoDao extends DatabaseAccessor<AppDatabase> with _$MemoDaoMixin {
  MemoDao(super.db);

  Future<int> insertMemo({
    required String title,
    required String transcript,
    required String? audioFilePath,
    required int durationMs,
  }) {
    final now = DateTime.now();
    return into(memos).insert(MemosCompanion.insert(
      title: title,
      transcript: Value(transcript),
      audioFilePath: Value(audioFilePath),
      durationMs: Value(durationMs),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<Memo?> getMemoById(int id) {
    return (select(memos)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Memo>> getAllMemos() {
    return (select(memos)..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<List<Memo>> searchMemos(String query) {
    return (select(memos)
          ..where((m) => m.transcript.like('%$query%') | m.title.like('%$query%'))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<void> updateTranscript(int id, String newTranscript) {
    return (update(memos)..where((m) => m.id.equals(id))).write(
      MemosCompanion(
        transcript: Value(newTranscript),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteAudioFile(int id) {
    return (update(memos)..where((m) => m.id.equals(id))).write(
      MemosCompanion(
        audioFilePath: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteMemo(int id) {
    return (delete(memos)..where((m) => m.id.equals(id))).go();
  }
}
```

- [ ] **Step 6: tag_dao.dart を実装**

```dart
// lib/database/daos/tag_dao.dart
import 'package:drift/drift.dart';
import '../app_database.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, MemoTags, Memos])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  MemoDao get memoDao => db.memoDao;

  Future<int> createTag(String name) {
    return into(tags).insert(TagsCompanion.insert(
      name: name,
      createdAt: DateTime.now(),
    ));
  }

  Future<List<Tag>> getAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> addTagToMemo(int memoId, int tagId) {
    return into(memoTags).insert(MemoTagsCompanion.insert(
      memoId: memoId,
      tagId: tagId,
    ));
  }

  Future<void> removeTagFromMemo(int memoId, int tagId) {
    return (delete(memoTags)
          ..where((mt) => mt.memoId.equals(memoId) & mt.tagId.equals(tagId)))
        .go();
  }

  Future<List<Tag>> getTagsForMemo(int memoId) {
    final query = select(tags).join([
      innerJoin(memoTags, memoTags.tagId.equalsExp(tags.id)),
    ])
      ..where(memoTags.memoId.equals(memoId));
    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Memo>> getMemosByTag(int tagId) {
    final query = select(memos).join([
      innerJoin(memoTags, memoTags.memoId.equalsExp(memos.id)),
    ])
      ..where(memoTags.tagId.equals(tagId))
      ..orderBy([OrderingTerm.desc(memos.createdAt)]);
    return query.map((row) => row.readTable(memos)).get();
  }

  Future<void> deleteTag(int tagId) async {
    await (delete(memoTags)..where((mt) => mt.tagId.equals(tagId))).go();
    await (delete(tags)..where((t) => t.id.equals(tagId))).go();
  }
}
```

- [ ] **Step 7: コード生成実行**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

Expected: 生成ファイル作成（`app_database.g.dart`, `memo_dao.g.dart`, `tag_dao.g.dart`）

- [ ] **Step 8: テスト実行 → Pass 確認**

```bash
fvm flutter test test/database/
```

Expected: All tests passed

- [ ] **Step 9: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/database/ test/database/
git commit -m "feat: add drift database layer with Memo and Tag DAOs"
```

---

## Task 5: サービス層 — AuthService

**Files:**
- Create: `lib/services/auth_service.dart`
- Create: `test/services/auth_service_test.dart`

- [ ] **Step 1: テストを書く**

```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/services/auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<LocalAuthentication>()])
import 'auth_service_test.mocks.dart';

void main() {
  late MockLocalAuthentication mockLocalAuth;
  late AuthService authService;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    authService = AuthService(localAuth: mockLocalAuth);
  });

  group('AuthService', () {
    test('authenticate returns true on success', () async {
      when(mockLocalAuth.authenticate(
        localizedReason: anyNamed('localizedReason'),
        options: anyNamed('options'),
      )).thenAnswer((_) async => true);

      final result = await authService.authenticate();
      expect(result, isTrue);
    });

    test('authenticate returns false on failure', () async {
      when(mockLocalAuth.authenticate(
        localizedReason: anyNamed('localizedReason'),
        options: anyNamed('options'),
      )).thenAnswer((_) async => false);

      final result = await authService.authenticate();
      expect(result, isFalse);
    });

    test('isBiometricAvailable checks device support', () async {
      when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

      final result = await authService.isBiometricAvailable();
      expect(result, isTrue);
    });

    test('isBiometricAvailable returns false when not supported', () async {
      when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

      final result = await authService.isBiometricAvailable();
      expect(result, isFalse);
    });
  });
}
```

- [ ] **Step 2: テスト実行 → 失敗確認**

```bash
fvm flutter test test/services/auth_service_test.dart
```

- [ ] **Step 3: AuthService を実装**

```dart
// lib/services/auth_service.dart
import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication _localAuth;

  AuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'アプリのロックを解除してください',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 4: mockito コード生成 + テスト実行**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter test test/services/auth_service_test.dart
```

Expected: All tests passed

- [ ] **Step 5: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/services/auth_service.dart test/services/auth_service_test.dart
git commit -m "feat: add AuthService with biometric authentication"
```

---

## Task 6: サービス層 — ModelManager

**Files:**
- Create: `lib/services/model_manager.dart`

ModelManager は Flutter assets に依存するため、ユニットテストではなく実機/エミュレータで手動確認。

- [ ] **Step 1: model_manager.dart を実装**

`sherpa-onnx-flutter-guide.md` section 3.1 を参照して実装する。assets からドキュメントディレクトリへのコピー処理。対象ファイル: `model.int8.onnx`, `tokens.txt`, `silero_vad.onnx`。

- [ ] **Step 2: コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/services/model_manager.dart
git commit -m "feat: add ModelManager for onnx model asset extraction"
```

---

## Task 7: サービス層 — SpeechRecognitionService

**Files:**
- Create: `lib/services/speech_recognition_service.dart`
- Create: `test/services/speech_recognition_service_test.dart`

`sherpa-onnx-flutter-guide.md` section 3.2 を参照して実装する。

- [ ] **Step 1: テストを書く（インターフェース検証）**

sherpa_onnx はネイティブライブラリのため、状態遷移と公開 API のテストに集中する。

```dart
// test/services/speech_recognition_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/services/speech_recognition_service.dart';

void main() {
  group('SpeechRecognitionService', () {
    test('isInitialized is false before initialize', () {
      final service = SpeechRecognitionService();
      expect(service.isInitialized, isFalse);
    });

    test('results stream is broadcast', () {
      final service = SpeechRecognitionService();
      // broadcast stream は複数 listener を許可する
      service.results.listen((_) {});
      service.results.listen((_) {});
      service.dispose();
    });
  });
}
```

- [ ] **Step 2: SpeechRecognitionService を実装**

`sherpa-onnx-flutter-guide.md` section 3.2 のコードをベースに、以下の修正を含めて実装:
- Silero VAD モデルファイルパスを ModelManager から取得
- flush() の結果をストリームに同期的に追加
- stream.free() を確実に呼ぶ

- [ ] **Step 3: テスト → Pass + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/services/speech_recognition_service.dart test/services/speech_recognition_service_test.dart
git commit -m "feat: add SpeechRecognitionService with VAD + SenseVoice"
```

---

## Task 8: サービス層 — AudioRecordingService

**Files:**
- Create: `lib/services/audio_recording_service.dart`
- Create: `test/services/audio_recording_service_test.dart`

- [ ] **Step 1: テストを書く（状態遷移）**

```dart
// test/services/audio_recording_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/services/audio_recording_service.dart';

void main() {
  group('AudioRecordingService', () {
    test('initial state is not recording', () {
      final service = AudioRecordingService();
      expect(service.isRecording, isFalse);
      expect(service.currentFilePath, isNull);
    });

    test('throws if stopRecording called when not recording', () async {
      final service = AudioRecordingService();
      final result = await service.stopRecording();
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: AudioRecordingService を実装**

`sherpa-onnx-flutter-guide.md` section 3.3 をベースに、以下を追加:
- `stopRecording()` で PCM バッファを WAV ファイルとして書き込む処理
- WAV ヘッダ生成ユーティリティ
- `onAudioData` コールバックで Float32 変換済みデータを提供
- バックグラウンド録音対応（iOS/Android のプラットフォーム設定は Task 2 で完了済み）

- [ ] **Step 3: テスト → Pass + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/services/audio_recording_service.dart test/services/audio_recording_service_test.dart
git commit -m "feat: add AudioRecordingService with WAV file writing"
```

---

## Task 9: サービス層 — AudioPlaybackService + ShareService + DatabaseService

**Files:**
- Create: `lib/services/audio_playback_service.dart`
- Create: `lib/services/share_service.dart`
- Create: `lib/services/database_service.dart`
- Create: `test/services/audio_playback_service_test.dart`

- [ ] **Step 1: AudioPlaybackService テストを書く**

```dart
// test/services/audio_playback_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/services/audio_playback_service.dart';

void main() {
  group('AudioPlaybackService', () {
    test('initial state is stopped', () {
      final service = AudioPlaybackService();
      expect(service.isPlaying, isFalse);
    });
  });
}
```

- [ ] **Step 2: 3つのサービスを実装**

`audio_playback_service.dart`: just_audio ラッパー（play, pause, seek, position/duration ストリーム）
`share_service.dart`: share_plus ラッパー（テキスト共有）
`database_service.dart`: AppDatabase の Riverpod Provider

- [ ] **Step 3: テスト → Pass + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/services/ test/services/
git commit -m "feat: add AudioPlayback, Share, and Database services"
```

---

## Task 10: Models（freezed）

**Files:**
- Create: `lib/models/recording_state.dart`
- Create: `lib/models/playback_state.dart`
- Create: `lib/models/memo_result.dart`
- Create: `lib/models/transcription_result.dart`

- [ ] **Step 1: 4つの freezed モデルを作成**

```dart
// lib/models/recording_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'recording_state.freezed.dart';

@freezed
sealed class RecordingState with _$RecordingState {
  const factory RecordingState.idle() = RecordingIdle;
  const factory RecordingState.recording({required String filePath}) = Recording;
  const factory RecordingState.processing() = RecordingProcessing;
}
```

```dart
// lib/models/playback_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'playback_state.freezed.dart';

@freezed
sealed class PlaybackState with _$PlaybackState {
  const factory PlaybackState.stopped() = PlaybackStopped;
  const factory PlaybackState.playing({
    required Duration position,
    required Duration duration,
  }) = Playing;
  const factory PlaybackState.paused({
    required Duration position,
    required Duration duration,
  }) = Paused;
}
```

```dart
// lib/models/memo_result.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'memo_result.freezed.dart';

@freezed
class MemoResult with _$MemoResult {
  const factory MemoResult({
    required String filePath,
    required String transcript,
    required int durationMs,
  }) = _MemoResult;
}
```

```dart
// lib/models/transcription_result.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'transcription_result.freezed.dart';

@freezed
class TranscriptionResult with _$TranscriptionResult {
  const factory TranscriptionResult({
    required String text,
    required bool isFinal,
    String? detectedLanguage,
  }) = _TranscriptionResult;
}
```

- [ ] **Step 2: コード生成 + コミット**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/models/
git commit -m "feat: add freezed models (RecordingState, PlaybackState, MemoResult, TranscriptionResult)"
```

---

## Task 11: App Shell（main.dart + app.dart + router.dart + AuthState）

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/core/router.dart`
- Create: `test/features/auth/auth_state_test.dart`
- Create: `test/features/settings/settings_controller_test.dart`

- [ ] **Step 1: AuthState + ThemeSetting のテストを書く**

```dart
// test/features/auth/auth_state_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/core/router.dart'; // authStateProvider はここに定義

void main() {
  group('AuthState', () {
    test('initial state is unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(authStateProvider), isFalse);
    });

    test('authenticate sets state to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authStateProvider.notifier).authenticate();
      expect(container.read(authStateProvider), isTrue);
    });

    test('lock sets state to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authStateProvider.notifier).authenticate();
      container.read(authStateProvider.notifier).lock();
      expect(container.read(authStateProvider), isFalse);
    });
  });
}
```

```dart
// test/features/settings/settings_controller_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koememo/features/settings/settings_controller.dart';

void main() {
  group('ThemeSetting', () {
    test('default theme is system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeSettingProvider), ThemeMode.system);
    });
  });
}
```

- [ ] **Step 2: テスト実行 → 失敗確認**

- [ ] **Step 3: router.dart を実装（AuthState Provider + GoRouter）**

GoRouter 定義。`redirect` で `authStateProvider` を参照し、未認証なら `/auth` へ。録音中（`recordingControllerProvider` が `Recording` 状態）なら認証スキップ。

- [ ] **Step 4: settings_controller.dart を実装**

```dart
// lib/features/settings/settings_controller.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_controller.g.dart';

@riverpod
class ThemeSetting extends _$ThemeSetting {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _loadSaved();
    return ThemeMode.system;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
```

- [ ] **Step 5: app.dart を実装**

MaterialApp.router + GoRouter + テーマ切替（ライト/ダーク/システム）。`AppTheme.light()` / `AppTheme.dark()` を使用。

- [ ] **Step 6: main.dart を書き換え**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KoememoApp()));
}
```

- [ ] **Step 7: コード生成 + テスト → Pass + コミット**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/main.dart lib/app.dart lib/core/router.dart lib/features/settings/ test/features/
git commit -m "feat: add app shell with GoRouter, auth state, and theme switching"
```

---

## Task 12: Feature — Auth Screen

**Files:**
- Create: `lib/features/auth/auth_screen.dart`

- [ ] **Step 1: auth_screen.dart を実装**

アプリ起動時に自動的に生体認証ダイアログを表示。成功なら `authStateProvider.notifier.authenticate()` を呼んでホームへ遷移。失敗なら再試行ボタン表示。

- [ ] **Step 2: app.dart に WidgetsBindingObserver を追加**

`didChangeAppLifecycleState` で `AppLifecycleState.resumed` 検知時、録音中でなければ `authStateProvider.notifier.lock()` を呼んで認証画面にリダイレクト。

- [ ] **Step 3: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/features/auth/ lib/app.dart
git commit -m "feat: add auth screen with biometric authentication and lifecycle guard"
```

---

## Task 13: Feature — Recording (録音 + リアルタイム文字起こし)

**Files:**
- Create: `lib/features/recording/recording_controller.dart`
- Create: `lib/features/recording/recording_screen.dart`
- Create: `lib/features/recording/widgets/waveform_indicator.dart`
- Create: `lib/features/recording/widgets/live_transcript_view.dart`
- Create: `test/features/recording/recording_controller_test.dart`

- [ ] **Step 1: recording_controller テストを書く**

```dart
// test/features/recording/recording_controller_test.dart
// RecordingController の状態遷移テスト:
// - 初期状態は idle
// - startRecording() → recording 状態
// - stopRecording() → processing → idle + MemoResult 返却
// サービスは mockito でモック
```

- [ ] **Step 2: テスト実行 → 失敗確認**

- [ ] **Step 3: recording_controller.dart を実装**

Riverpod 3 Notifier。`RecordingState` を state として管理。
- `startRecording()`: AudioRecordingService.startRecording() + SpeechRecognitionService への PCM フロー開始
- `stopRecording()`: 停止 → flush → MemoDao に保存 → MemoResult 返却
- `liveTranscript`: SpeechRecognitionService.results ストリームを購読して文字列を蓄積

- [ ] **Step 4: テスト → Pass 確認**

- [ ] **Step 5: recording_screen.dart + widgets を実装**

画面構成:
- AppBar: 「録音」ラベル
- 中央: WaveformIndicator（録音中のアニメーション）
- 下部: LiveTranscriptView（リアルタイムテキスト表示）
- FAB: 録音開始/停止ボタン（マイクアイコン ↔ 停止アイコン）
- 停止後に自動的にメモ詳細画面へ遷移

- [ ] **Step 6: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/features/recording/ test/features/recording/
git commit -m "feat: add recording feature with real-time transcription"
```

---

## Task 14: Feature — Memo List (一覧 + 検索 + タグフィルタ)

**Files:**
- Create: `lib/features/memo_list/memo_list_screen.dart`
- Create: `lib/features/memo_list/memo_list_controller.dart`
- Create: `lib/features/memo_list/widgets/memo_card.dart`
- Create: `lib/features/memo_list/widgets/search_bar.dart`
- Create: `lib/features/memo_list/widgets/tag_filter_chips.dart`
- Create: `test/features/memo_list/memo_list_controller_test.dart`

- [ ] **Step 1: memo_list_controller テストを書く**

Provider テスト。MemoDao をモックして:
- メモ一覧取得（日時降順）
- テキスト検索
- タグフィルタ

- [ ] **Step 2: テスト実行 → 失敗確認**

- [ ] **Step 3: memo_list_controller.dart を実装**

```dart
// searchQuery と tagId を引数に持つ関数型 Provider
// MemoDao.getAllMemos(), searchMemos(), TagDao.getMemosByTag() を使い分け
```

- [ ] **Step 4: テスト → Pass 確認**

- [ ] **Step 5: 画面 + widgets を実装**

画面構成:
- AppBar: 「メモ一覧」ラベル + 設定アイコン（→ /settings）
- SearchBar: テキスト検索入力
- TagFilterChips: 横スクロールのタグチップ（タップでフィルタ）
- ListView: MemoCard のリスト（タイトル、日時、文字起こしプレビュー）
- FAB: マイクアイコン（→ /recording）
- 空状態: 「メモがありません」表示

- [ ] **Step 6: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/features/memo_list/ test/features/memo_list/
git commit -m "feat: add memo list with search and tag filtering"
```

---

## Task 15: Feature — Memo Detail (詳細 + 再生 + タグ + Share + 削除)

**Files:**
- Create: `lib/features/memo_detail/memo_detail_controller.dart` — MemoEditor Notifier（設計文書 section 6 の MemoEditor に対応。削除・タグ・音声削除はここに集約）
- Create: `lib/features/memo_detail/memo_detail_screen.dart`
- Create: `lib/features/memo_detail/widgets/audio_player_bar.dart`
- Create: `lib/features/memo_detail/widgets/tag_editor.dart`
- Create: `test/features/memo_detail/memo_detail_controller_test.dart`
- Create: `test/features/memo_detail/audio_player_test.dart` — AudioPlayer Notifier の状態遷移テスト

**責務の明確化:** 設計文書の `MemoEditor` は `memo_detail_controller.dart` に実装する。Task 16 の `memo_edit_controller.dart` はテキスト編集の UI 状態管理のみ（transcript の一時バッファ、保存処理）を担当し、DB への書き込みは `MemoEditor.updateTranscript()` を呼ぶ。

- [ ] **Step 1: memo_detail_controller テストを書く**

- メモ取得
- タグ追加・削除
- 音声ファイル削除（テキスト残る）
- メモ全体削除

- [ ] **Step 2: AudioPlayer Notifier テストを書く**

```dart
// test/features/memo_detail/audio_player_test.dart
// AudioPlayer の状態遷移テスト:
// - 初期状態は stopped
// - play() → playing 状態
// - pause() → paused 状態
// - seek() → position 更新
// AudioPlaybackService は mockito でモック
```

- [ ] **Step 3: テスト実行 → 失敗確認**

- [ ] **Step 4: memo_detail_controller.dart を実装**

MemoDetail Provider（memoId → Memo 取得）+ MemoEditor Notifier（CRUD + タグ操作 + 音声削除）+ AudioPlayer Notifier

- [ ] **Step 4: テスト → Pass 確認**

- [ ] **Step 5: 画面 + widgets を実装**

画面構成:
- AppBar: 「メモ詳細」ラベル + 編集ボタン（→ /memo/:id/edit）+ 共有ボタン + 削除メニュー（メモ全体削除 / 音声のみ削除）
- AudioPlayerBar: 再生/一時停止ボタン + シークバー + 経過時間/総時間（audioFilePath が null なら非表示）
- テキスト表示エリア: 文字起こしテキスト全文
- TagEditor: 既存タグ表示 + 追加入力欄

- [ ] **Step 6: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/features/memo_detail/ test/features/memo_detail/
git commit -m "feat: add memo detail with playback, tags, share, and delete"
```

---

## Task 16: Feature — Memo Edit (テキスト編集)

**Files:**
- Create: `lib/features/memo_edit/memo_edit_screen.dart`
- Create: `lib/features/memo_edit/memo_edit_controller.dart`
- Create: `test/features/memo_edit/memo_edit_controller_test.dart`

- [ ] **Step 1: memo_edit_controller テストを書く**

- テキスト更新が DB に反映される
- 空文字での保存を防止

- [ ] **Step 2: テスト → 失敗確認 → 実装 → Pass**

- [ ] **Step 3: 画面を実装**

画面構成:
- AppBar: 「メモ編集」ラベル + 保存ボタン
- TextField: 複数行、現在の transcript をプリロード
- 保存後にメモ詳細画面に戻る

- [ ] **Step 4: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/features/memo_edit/ test/features/memo_edit/
git commit -m "feat: add memo edit screen for transcript editing"
```

---

## Task 17: Feature — Settings (テーマ切替)

**Files:**
- Create: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: settings_screen.dart を実装**

画面構成:
- AppBar: 「設定」ラベル
- ListTile: テーマ設定（ライト / ダーク / システム）ラジオボタン
- ThemeSetting Provider で状態管理

- [ ] **Step 2: 品質ゲート + コミット**

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
git add lib/features/settings/settings_screen.dart
git commit -m "feat: add settings screen with theme switching"
```

---

## Task 18: 最終統合 + 品質ゲート

- [ ] **Step 1: 全テスト実行**

```bash
fvm flutter test
```

Expected: All tests passed

- [ ] **Step 2: Static analysis**

```bash
fvm flutter analyze
```

Expected: No issues found

- [ ] **Step 3: Formatter**

```bash
fvm dart format --set-exit-if-changed .
```

Expected: 差分なし

- [ ] **Step 4: iOS ビルド**

```bash
fvm flutter build ios --no-codesign
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Android ビルド**

```bash
fvm flutter build apk
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: 最終コミット**

```bash
git add -A
git commit -m "chore: final quality gate pass - all tests, analyze, format, build OK"
```
