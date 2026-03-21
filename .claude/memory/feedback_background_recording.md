---
name: feedback-background-recording
description: 録音はバックグラウンド・スリープ中も継続必須。フォアグラウンド必須は不便と明確に指摘あり
type: feedback
---

録音機能はバックグラウンド・スリープ中も中断せず継続すること。

**Why:** アプリがアクティブでないと録音できないのは極めて不便とユーザーが明言。

**How to apply:** 録音機能の設計・実装時に、必ずバックグラウンド継続を前提にする。iOS の Background Audio / Android の Foreground Service が必須。
