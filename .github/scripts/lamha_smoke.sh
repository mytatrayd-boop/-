#!/usr/bin/env bash
# تشخيص (بلاغ المالك: لمحة أندرويد تنهار عند الفتح على جواله). على المحاكي:
# ١) إن مُرِّرت نسخة قديمة: تُثبَّت وتُشغَّل (تكتب إعداداتها)، ثم تُحدَّث فوقها بالجديدة كما يفعل Google Play.
# ٢) تشغيل الجديدة وطباعة سجل الأعطال.
# لا يفشل الخطوة: الناتج في سجل الـ job.
PKG=sa.lamha.lamha
NEW="${1:?new apk}"
OLD="${2:-}"
OUT="${3:-smoke}"
mkdir -p "$OUT"

launch() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }
alive() { adb shell pidof "$PKG" || echo "PROCESS NOT RUNNING"; }

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

adb logcat -d > "$OUT/full.log"
echo "=== filtered log"; grep -E "AndroidRuntime|FATAL|OutOfMemory|Too many|LamhaWidget|ANR|lowmemory" "$OUT/full.log" | tail -60

# ---------------------------------------------------------------------------------------------
# الأذان (DECISIONS ٢٨): تفعيله من الإعدادات المحفوظة، والتحقق من جدولة المنبهات، ثم «تجربة الصوت»
# وفحص الإشعار وقناته وصوته. يحتاج root (emulator google_apis).
echo "=== adhan: seed settings with adhan enabled"
adb root >/dev/null 2>&1; sleep 3
adb shell am force-stop "$PKG"
UID_APP=$(adb shell stat -c %u "/data/data/$PKG" | tr -d '\r')
python3 - > "$OUT/prefs.xml" <<'PY'
import json, html
s = {"cityId": "gps", "cityName": "أبها", "latitude": 18.2164, "longitude": 42.5053, "timeZone": "Asia/Riyadh",
     "prayerMethod": "ummAlQura", "deposits": ["salary"], "opacity": 100,
     "adhan": {"enabled": True, "prayers": ["fajr", "dhuhr", "asr", "maghrib", "isha"], "sound": "full"}}
print("<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n  <string name=\"flutter.settings\">%s</string>\n</map>"
      % html.escape(json.dumps(s, ensure_ascii=False), quote=True))
PY
adb push "$OUT/prefs.xml" /data/local/tmp/prefs.xml >/dev/null
adb shell "mkdir -p /data/data/$PKG/shared_prefs && cp /data/local/tmp/prefs.xml /data/data/$PKG/shared_prefs/FlutterSharedPreferences.xml && chown $UID_APP:$UID_APP /data/data/$PKG/shared_prefs/FlutterSharedPreferences.xml && restorecon -R /data/data/$PKG/shared_prefs"
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS
adb shell appops set "$PKG" SCHEDULE_EXACT_ALARM allow
adb logcat -c
launch; sleep 30
echo "process alive:"; alive
echo "=== adhan: alarms scheduled for the app (expect ~60)"
adb shell dumpsys alarm | grep -c "$PKG" || true
adb shell dumpsys alarm | grep -B1 -A3 "ScheduledNotificationReceiver" | head -14

# اضغط «تجربة الصوت»: مرّر الشاشة حتى يظهر الزر ثم المس مركزه.
find_bounds() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | python3 -c "
import re, sys
x = sys.stdin.read()
for m in re.finditer(r'<node[^>]*?(?:text|content-desc)=\"([^\"]*)\"[^>]*?bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', x):
    if '$1' in m.group(1):
        a = [int(v) for v in m.groups()[1:]]
        print((a[0] + a[2]) // 2, (a[1] + a[3]) // 2); break
"; }
POS=""
for i in 1 2 3 4 5 6 7 8; do
  POS=$(find_bounds "تجربة الصوت")
  [ -n "$POS" ] && break
  adb shell input swipe 540 1900 540 500 300; sleep 1
done
echo "test button at: ${POS:-NOT FOUND}"
adb exec-out screencap -p > "$OUT/adhan_section.png"
if [ -n "$POS" ]; then
  adb shell input tap $POS; sleep 4
  echo "=== adhan: notification posted by the test button"
  adb shell dumpsys notification --noredact | grep -E "pkg=$PKG|channel=adhan|sound=|android.title|إيقاف|Stop" | head -20
  echo "=== adhan: channels"
  adb shell dumpsys notification | grep -A6 "adhan_full" | head -14
fi
adb exec-out screencap -p > "$OUT/adhan_after_test.png"
adb logcat -d > "$OUT/full2.log"
echo "=== adhan: crashes"; adb logcat -d -b crash | tail -30
