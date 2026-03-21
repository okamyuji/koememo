---
name: sherpa-onnx-integration
description: Use when implementing or modifying speech recognition, model management, VAD configuration, or any sherpa_onnx related code. Triggers on keywords like OfflineRecognizer, SenseVoice, VAD, voice activity detection, model.int8.onnx, tokens.txt, acceptWaveform, PCM conversion, or transcription features.
---

# sherpa_onnx Integration

## Overview

koememo は sherpa_onnx を使ったオンデバイス音声認識アプリ。SenseVoice (非ストリーミング) + Silero VAD で simulated streaming を実現する。

**IMPORTANT:** 実装の詳細は必ず `sherpa-onnx-flutter-guide.md` を参照すること。このスキルはガイドの要点と判断基準を提供する。

## When to Use

- sherpa_onnx 関連のコード追加・修正時
- 音声認識の精度やパフォーマンス問題の調査時
- モデルファイルの管理やコピー処理の実装時
- VAD パラメータの調整時
- PCM データ変換の実装時

**When NOT to use:** UI のみの変更、DB スキーマ変更、録音に関係しない機能追加

## Critical Rules

1. **sherpa_onnx は Flutter assets を直接読めない。** `ModelManager` で Documents ディレクトリにコピーしてからパスを渡すこと
2. **PCM は Int16 → Float32 変換が必須。** `int16Data[i] / 32768.0` で正規化すること
3. **numThreads は 2 を使うこと。** 4 にしても改善なし、電力消費が増える
4. **language は `'ja'` を明示指定すること。** 自動検出より認識精度が上がる
5. **初期化は 2〜5 秒かかる。** アプリ起動直後に非同期で行い、UI をブロックしないこと

## Quick Reference

| 設定項目 | 値 | 理由 |
|---------|-----|------|
| sampleRate | 16000 | sherpa_onnx の要件 |
| numChannels | 1 (mono) | sherpa_onnx の要件 |
| numThreads | 2 | モバイル最適値 |
| VAD threshold | 0.5 | 感度と誤検出のバランス |
| minSilenceDuration | 0.5 | セグメント区切り。短すぎると過分割 |
| maxSpeechDuration | 30.0 | メモ用途に十分 |
| useInverseTextNormalization | true | 数字をアラビア数字で出力 |

## Architecture

```
マイク (16kHz Int16 PCM)
  → Float32 変換
    → Silero VAD (音声区間検出)
      → SenseVoice OfflineRecognizer (セグメント単位認識)
        → テキスト結果を UI にストリーム表示
```

## Common Mistakes

| ミス | 正しい対処 |
|------|-----------|
| assets から直接モデルを読む | `ModelManager.ensureModelReady()` でコピー後のパスを使う |
| Int16 PCM をそのまま渡す | `/ 32768.0` で Float32 に変換 |
| stream を free し忘れ | 認識後は必ず `stream.free()` |
| flush を呼ばずに録音終了 | `_speechService.flush()` で残バッファを処理 |
| Android で onnx が圧縮される | `aaptOptions { noCompress 'onnx' }` を設定 |

## Full Reference

**MUST READ:** 実装コード・プラットフォーム設定・モデルダウンロード手順は `sherpa-onnx-flutter-guide.md` (プロジェクトルート) に全て記載。
