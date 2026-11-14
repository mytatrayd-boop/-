#!/usr/bin/env bash
# حارس عام: يفشل إن وجد نمط مفتاح API معروفاً (AIza..., AKIA...) أو مفتاحاً خاصاً في أي ملف متتبَّع أو غير مستثنى.
set -uo pipefail
cd "$(dirname "$0")/.."
if git rev-parse --git-dir >/dev/null 2>&1; then
  FILES="$(git ls-files -co --exclude-standard -- . | grep -v '^tool/check_no_secrets.sh$')"
else
  FILES="$(find . -type f -not -path './.dart_tool/*' -not -path './build/*' -not -path './.git/*' -not -name .env -not -path './tool/check_no_secrets.sh')"
fi
FAIL=0
PATTERN='AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
if [ -n "$FILES" ] && printf '%s\n' "$FILES" | xargs -d '\n' grep -lE "$PATTERN" 2>/dev/null; then
  echo "check_no_secrets: FAIL: key-like pattern found in the files above"; FAIL=1
fi
[ "$FAIL" -eq 0 ] && echo "check_no_secrets: OK"
exit "$FAIL"
