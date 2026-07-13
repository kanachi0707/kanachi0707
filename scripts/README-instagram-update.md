# Instagram Latest JSON Update

このスクリプト群は Instagram の最新投稿を取得し、GitHub Pages へ自動公開します。

実行例:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-instagram-json.ps1
```

タスクスケジューラと同じ一連の処理を実行:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-instagram-update.ps1
```

動き:
- Instagram プロフィールページから最新投稿 shortcode を取得
- `instagram-latest.json` の `url` と `updatedAt` を更新
- 取得失敗時は既存URL、なければ固定フォールバック投稿を保持
- `status` と `error` を JSON に残す
- 取得成功時だけ対象JSON/JSをcommitして `origin/main` へpush
- 取得失敗時はpushせず、公開中の正常な投稿を維持

注意:
- Instagram 側の HTML 構造変更で壊れる可能性があります
- その場合でもサイトは `fallbackUrl` を表示できます
