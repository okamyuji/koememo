# koememo

ボイスメモアプリ。録音 → sherpa_onnx でオンデバイス文字起こし → メモとして保存・閲覧。

## IMPORTANT: fvm 必須

- Flutter SDK は fvm 3.41.5 でバージョン固定
- `flutter`, `dart` コマンドは **全て** `fvm flutter`, `fvm dart` 経由で実行すること
- analyze, format, test, build も全て fvm 経由: `fvm flutter analyze`, `fvm dart format` 等

## IMPORTANT: 品質ゲート

以下が全て Pass しないと実装完了とみなさない:

```bash
fvm flutter analyze                          # warning/error ゼロ
fvm dart format --set-exit-if-changed .      # 差分ゼロ
fvm flutter test                             # 全テスト Pass
fvm flutter build ios --no-codesign          # iOS ビルド成功
fvm flutter build apk                        # Android ビルド成功
```

## IMPORTANT: 設計原則

- Feature-first 構成: `lib/features/<機能名>/` 配下に screen, controller, widgets/ をまとめる
- 状態管理は Riverpod 3系（flutter_riverpod ^3.3.1 + riverpod_annotation ^4.0.2）
- 一部 provider は手書き（drift 型との互換性やパフォーマンス上の理由）
- サービス層 (`lib/services/`) はドメイン非依存の技術ラッパーのみ
- モデル (`lib/models/`) は freezed で immutable に定義
- 認証ライフサイクルは GoF State パターン（`lib/core/auth_lifecycle.dart`）

## 技術スタック

- Flutter 3.41.5 (fvm) / Dart ^3.11.0
- 状態管理: Riverpod 3系 + riverpod_generator
- ルーティング: GoRouter（手書き `Provider<GoRouter>`、`@Riverpod` ではない）
- 音声認識: sherpa_onnx ^1.12.0 (SenseVoice int8 + Silero VAD)
- 録音: record ^6.2.0
- 音声再生: just_audio ^0.10.5
- 生体認証: local_auth ^3.0.1
- ストレージ: drift ^2.25.0 + drift_flutter ^0.2.8

## 構成

```text
lib/
├── main.dart              # エントリポイント（sherpa.initBindings() 必須）
├── app.dart               # MaterialApp.router + 認証ライフサイクル
├── core/
│   ├── constants.dart     # モデルパス、サンプルレート等
│   ├── theme.dart         # Material 3 テーマ
│   ├── router.dart        # GoRouter + AuthState / RecordingActive
│   ├── auth_lifecycle.dart # State パターン認証管理
│   └── utils/pcm_converter.dart
├── services/              # 技術ラッパー（8ファイル）
├── features/              # auth, recording, memo_list, memo_detail, memo_edit, settings
├── models/                # recording_state, playback_state, memo_result, transcription_result
└── database/              # app_database + daos/ (memo_dao, tag_dao)
assets/models/sense-voice/ # model.int8.onnx (228MB), tokens.txt, silero_vad.onnx
```

## コマンド

```bash
fvm flutter run                        # 実行
fvm flutter test                       # テスト（47件）
fvm dart run build_runner build        # コード生成 (riverpod, drift, freezed)
fvm flutter build ios --release        # iOS ビルド
fvm flutter build apk --release        # Android ビルド
```

## 詳細ドキュメント

- 設計文書: `docs/2026-03-21-koememo-design.md`
- 実装計画: `docs/plans/2026-03-21-koememo-implementation.md`
- sherpa_onnx 実装詳細: `sherpa-onnx-flutter-guide.md`

## 罠・注意点

- `sherpa.initBindings()` を `main.dart` で必ず呼ぶこと（未呼び出しだと "Please initialize sherpa-onnx first" エラー）
- モデルファイル (228MB) は assets に含めるが、初回起動時に `ModelManager` が Documents にコピーする設計。直接 assets から読み込まないこと
- PCM データは Int16 で取得されるが、sherpa_onnx は Float32 を要求。`pcm_converter.dart` で変換（バイトアライメントに注意）
- Android は `FlutterFragmentActivity` が必須（`FlutterActivity` だと local_auth の生体認証ダイアログが表示されない）
- iOS の microphone/FaceID permission は Info.plist + runtime の両方で設定が必要
- iOS: `UIBackgroundModes: audio` でバックグラウンド録音を有効化
- GoRouter provider は手書き `Provider<GoRouter>` を使用（`@Riverpod` だと startup crash する）
- `ref.listen` で authState/recordingActive の変更を監視し `goRouter.refresh()` で redirect 再評価（`app.dart`）
- 録音状態は `RecordingActive` boolean provider で管理（router と auth_lifecycle の両方から参照）
- モデルファイルは .gitignore 対象。手動で `assets/models/sense-voice/` に配置が必要

## トリガールール

- 新しい feature を追加したら → `lib/features/<名前>/` ディレクトリを作り、screen + controller + widgets/ の構成にすること
- 新しいサービスを追加したら → `lib/services/` に置き、feature から直接外部パッケージを呼ばないこと
- モデルを変更したら → コード生成を実行: `fvm dart run build_runner build`
- sherpa_onnx 関連の実装をするとき → 必ず `sherpa-onnx-flutter-guide.md` を読んでから着手すること
- 実装が完了したら → 品質ゲートの全コマンドを実行して Pass を確認すること
- iOS にインストールする際 → `fvm flutter clean` 後にビルドすること（コード署名破損の回避）
