#!/usr/bin/env bash
# يثبّت نسخة الإصدار على المحاكي ويشغّلها ويطبع سجل الأعطال، ثم يجرّب مسار تحديث الودجت في المستقبل.
# تشخيص فقط (بلاغ المالك: لمحة أندرويد تنطفئ عند الفتح). لا يفشل الخطوة: الناتج في سجل الـ job.
PKG=sa.lamha.lamha
APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
OUT="${2:-smoke}"
mkdir -p "$OUT"
adb install -r "$APK" || { echo "INSTALL FAILED"; exit 0; }
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 30
adb exec-out screencap -p > "$OUT/launch.png"
echo "=== process after launch"; adb shell pidof "$PKG" || echo "PROCESS NOT RUNNING"
echo "=== memory"; adb shell dumpsys meminfo "$PKG" | head -25
# مسار تحديث الودجت كما يفعله النظام (مُعرّف وهمي: النظام يرفضه بعد أن يبني المستقبل الودجت كاملة).
adb shell am broadcast -n "$PKG/.widget.LamhaWidgetReceiver" -a android.appwidget.action.APPWIDGET_UPDATE --eia appWidgetIds 1
sleep 5
echo "=== process after widget broadcast"; adb shell pidof "$PKG" || echo "PROCESS NOT RUNNING"
adb logcat -d > "$OUT/full.log"
adb logcat -d -b crash > "$OUT/crash.log"
echo "=== crash buffer"; tail -120 "$OUT/crash.log"
echo "=== filtered log"; grep -E "AndroidRuntime|FATAL|OutOfMemory|Too many|LamhaWidget|sa\.lamha|ANR|lowmemory|Out of memory|E/flutter" "$OUT/full.log" | tail -200
