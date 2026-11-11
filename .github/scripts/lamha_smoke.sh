#!/usr/bin/env bash
# تشخيص (بلاغ المالك: لمحة أندرويد تنهار عند الفتح على جواله). على المحاكي:
# ١) إن مُرِّرت نسخة قديمة: تُثبَّت وتُشغَّل (تكتب إعداداتها)، ثم تُحدَّث فوقها بالجديدة كما يفعل Google Play.
# ٢) تشغيل الجديدة وطباعة سجل الأعطال، ثم فرض انهيار (am crash) والتحقق من أن شاشة «تشخيص لمحة» تعرضه.
# لا يفشل الخطوة: الناتج في سجل الـ job.
PKG=sa.lamha.lamha
NEW="${1:?new apk}"
OLD="${2:-}"
OUT="${3:-smoke}"
mkdir -p "$OUT"

launch() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }
alive() { adb shell pidof "$PKG" || echo "PROCESS NOT RUNNING"; }
ui_text() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | grep -o 'text="[^"]\{1,\}"' | head -${1:-60}; }

if [ -n "$OLD" ]; then
  echo "=== (1) install OLD version and run it"
  adb install -r "$OLD" || echo "OLD INSTALL FAILED"
  launch; sleep 25
  echo "old alive:"; alive
  adb shell am force-stop "$PKG"
  echo "=== (2) upgrade to NEW over OLD (data kept)"
  adb install -r "$NEW" || { echo "UPGRADE INSTALL FAILED"; exit 0; }
else
  adb install -r "$NEW" || { echo "INSTALL FAILED"; exit 0; }
fi

adb logcat -c
launch; sleep 30
adb exec-out screencap -p > "$OUT/launch.png"
echo "=== process after launch"; alive
echo "=== meminfo"; adb shell dumpsys meminfo "$PKG" | sed -n 1,12p
adb logcat -d -b crash > "$OUT/crash.log"
echo "=== crash buffer (launch)"; tail -80 "$OUT/crash.log"

echo "=== forcing a crash (am crash) then opening the diagnostics screen"
adb shell am crash "$PKG"; sleep 4
echo "process after am crash:"; alive
adb shell am start -n "$PKG/.DiagActivity" >/dev/null 2>&1; sleep 5
adb exec-out screencap -p > "$OUT/diag.png"
echo "=== diagnostics screen text"; ui_text 80
adb logcat -d > "$OUT/full.log"
echo "=== filtered log"; grep -E "AndroidRuntime|FATAL|OutOfMemory|Too many|LamhaWidget|ANR|lowmemory" "$OUT/full.log" | tail -60
