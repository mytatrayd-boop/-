#!/usr/bin/env bash
# يولّد ملفات المفتاح غير المتتبَّعة من .env. بلا .env أو بمفتاح فارغ: ملفات فارغة القيمة (البناء يعمل بلا مفتاح).
set -euo pipefail
cd "$(dirname "$0")/.."
KEY=""
if [ -f .env ]; then
  KEY="$(grep -E '^GOOGLE_MAPS_API_KEY=' .env | head -n1 | cut -d= -f2- | tr -d '\r"' || true)"
fi
KEY="${KEY:-${GOOGLE_MAPS_API_KEY:-}}"
mkdir -p android ios/Flutter
printf 'GOOGLE_MAPS_API_KEY=%s\n' "$KEY" > android/secrets.properties
printf 'GOOGLE_MAPS_API_KEY=%s\n' "$KEY" > ios/Flutter/Secrets.xcconfig
if [ -z "$KEY" ]; then echo "gen_secrets: no key set; generated empty files (app builds without a map key)"; else echo "gen_secrets: generated"; fi
