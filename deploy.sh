#!/bin/bash
set -e

echo "=== コミット ==="
git add -A
git diff --cached --stat
read -p "コミットメッセージ: " msg
git commit -m "$msg"

echo ""
echo "=== プッシュ ==="
git push

echo ""
echo "=== ビルド ==="
rm -rf build
flutter build web --pwa-strategy none

echo ""
echo "=== デプロイ ==="
firebase deploy --only hosting --project kakeibo-1f1d8

echo ""
echo "=== 完了 ==="
echo "https://kakeibo-1f1d8.web.app"
