---
name: feature-scaffold
description: Use when creating a new feature module, adding a new screen, or scaffolding a new functional area in the app. Triggers on requests like "add recording screen", "create memo list", "new feature", or when adding any user-facing functionality.
---

# Feature Scaffold

## Overview

koememo は feature-first 構成を採用。新しい機能は `lib/features/<name>/` にまとめ、screen + controller + widgets の構成にする。

## When to Use

- 新しい画面・機能を追加するとき
- 既存 feature の構成を確認したいとき

**When NOT to use:** サービス層の追加（`lib/services/` に直接配置）、モデル追加（`lib/models/` に配置）

## Required Structure

新しい feature を作成したら、以下の構成を **必ず** 作ること:

```
lib/features/<feature_name>/
├── <feature_name>_screen.dart       # 画面 Widget (StatelessWidget + ConsumerWidget)
├── <feature_name>_controller.dart   # ビジネスロジック (Riverpod provider)
└── widgets/                         # feature 固有の子 Widget
    └── <descriptive_name>.dart
```

## Rules

1. **provider は feature 内に co-locate すること。** グローバルな providers ファイルを作らない
2. **feature から外部パッケージを直接呼ばないこと。** `lib/services/` を経由する
3. **feature 間の直接依存を避けること。** 共通ロジックは `lib/core/` か `lib/services/` に置く
4. **screen は薄くすること。** ロジックは controller に、表示は widgets/ に分離

## Naming Convention

| ファイル種別 | 命名規則 | 例 |
|------------|---------|-----|
| Screen | `<feature>_screen.dart` | `recording_screen.dart` |
| Controller | `<feature>_controller.dart` | `recording_controller.dart` |
| Widget | 機能を表す名前 | `waveform_indicator.dart` |
| Provider | controller 内に定義 | `recordingControllerProvider` |

## Existing Features

| Feature | 役割 |
|---------|------|
| `recording/` | 録音 + リアルタイム文字起こし |
| `memo_list/` | メモ一覧表示 |
| `memo_detail/` | メモ詳細・再生・再文字起こし |
