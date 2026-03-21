# koememo

ボイスメモアプリ。録音 → sherpa_onnx でオンデバイス文字起こし → メモとして保存・閲覧。

## IMPORTANT: fvm 必須

- Flutter SDK は fvm でバージョン固定すること
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

- Feature-first 構成を使うこと: `lib/features/<機能名>/` 配下に screen, controller, widgets/ をまとめる
- 状態管理は Riverpod 3系を使うこと（provider は features 内に co-locate）
- サービス層 (`lib/services/`) はドメイン非依存の技術ラッパーのみ置くこと
- モデル (`lib/models/`) は immutable な Dart クラスとし、freezed + json_serializable を使うこと

## 技術スタック

- Flutter (fvm でバージョン固定) / Dart
- 状態管理: Riverpod 3系 + riverpod_generator
- ルーティング: GoRouter
- 音声認識: sherpa_onnx (SenseVoice モデル, int8量子化)
- 録音: record パッケージ
- ストレージ: drift (SQLite ベース)

## 構成

```text
lib/
├── main.dart / app.dart
├── core/          # 定数, テーマ, ルーター, ユーティリティ
├── services/      # model_manager, speech_recognition, audio_recording, auth, etc.
├── features/      # auth/, recording/, memo_list/, memo_detail/, memo_edit/, settings/
├── models/        # memo, transcription_result
└── database/      # drift DB 定義, DAOs
assets/models/sense-voice/  # model.int8.onnx (228MB), tokens.txt
```

## コマンド

```bash
fvm flutter run                        # 実行
fvm flutter test                       # テスト
fvm dart run build_runner build        # コード生成 (riverpod, drift, freezed)
fvm flutter build ios --release        # iOS ビルド
fvm flutter build apk                  # Android ビルド
```

## 詳細ドキュメント

- 設計文書: `docs/2026-03-21-koememo-design.md` を参照
- sherpa_onnx 実装詳細: `sherpa-onnx-flutter-guide.md` を参照

## 罠・注意点

- sherpa_onnx のモデルファイル (228MB) は assets に含まれるが、初回起動時に `model_manager` が File System にコピーする設計。直接 assets から読み込まないこと
- 録音の PCM データは Int16 で取得されるが、sherpa_onnx は Float32 を要求する。`pcm_converter.dart` で変換すること
- iOS の microphone permission は Info.plist + runtime の両方で設定が必要
- 録音はバックグラウンド・スリープ中も継続必須。iOS: Background Audio、Android: Foreground Service

## トリガールール

- 新しい feature を追加したら → `lib/features/<名前>/` ディレクトリを作り、screen + controller + widgets/ の構成にすること
- 新しいサービスを追加したら → `lib/services/` に置き、feature から直接外部パッケージを呼ばないこと
- モデルを変更したら → コード生成を実行すること: `fvm dart run build_runner build`
- sherpa_onnx 関連の実装をするとき → 必ず `sherpa-onnx-flutter-guide.md` を読んでから着手すること
- 実装が完了したら → 品質ゲートの全コマンドを実行して Pass を確認すること
