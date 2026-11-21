#!/bin/sh
# ينسخ الموقع إلى docs/nafes-sim ليُنشر عبر GitHub Pages
set -e
cd "$(dirname "$0")/../.."
rm -rf docs/nafes-sim && mkdir -p docs/nafes-sim
cp -R apps/murtaqa/web/. docs/nafes-sim/
echo "نُسخ إلى docs/nafes-sim"
