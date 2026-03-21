---
name: feedback-commit-rules
description: コミットメッセージにAI名を入れない。コミット前に必ず analyze/lint/test/build を全て Pass させる
type: feedback
---

コミットメッセージに AI の名前（Claude, Co-Authored-By 等）を絶対に入れないこと。

**Why:** ユーザーが明示的に「AIの名前は絶対に入れずに」と指示。

**How to apply:** 全てのコミットで Co-Authored-By 行を含めない。コミット前に品質ゲート（analyze/format/test/build）を全て Pass させてからコミットする。
