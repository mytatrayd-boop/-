#!/usr/bin/env bash
# الأذان (DECISIONS ٢٨) على المحاكي: يفعّل الأذان بإعدادات محفوظة، ويتحقق من جدولة المنبهات، ثم يضغط «تجربة الصوت»
# ويفحص الإشعار وقناته وصوته. يحتاج root (emulator google_apis) وتثبيت التطبيق مسبقاً (lamha_smoke.sh).
# يُشغَّل بمهلة وتتبّع (bash -x) فيظهر في السجل آخر أمر إن تعلّق.
PKG=sa.lamha.lamha
OUT="${1:-smoke}"
mkdir -p "$OUT"
launch() { timeout 30 adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }
alive() { timeout 30 adb shell pidof "$PKG" || echo "PROCESS NOT RUNNING"; }
echo "=== adhan: seed settings with adhan enabled"
timeout 60 adb root >/dev/null 2>&1; sleep 3
timeout 60 adb shell am force-stop "$PKG"
UID_APP=$(timeout 60 adb shell stat -c %u "/data/data/$PKG" | tr -d '\r')
python3 - > "$OUT/prefs.xml" <<'PY'
import json, html
s = {"cityId": "gps", "cityName": "أبها", "latitude": 18.2164, "longitude": 42.5053, "timeZone": "Asia/Riyadh",
     "prayerMethod": "ummAlQura", "deposits": ["salary"], "opacity": 100,
     "adhan": {"enabled": True, "prayers": ["fajr", "dhuhr", "asr", "maghrib", "isha"], "sound": "full"}}
print("<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n  <string name=\"flutter.settings\">%s</string>\n</map>"
      % html.escape(json.dumps(s, ensure_ascii=False), quote=True))
PY
timeout 60 adb push "$OUT/prefs.xml" /data/local/tmp/prefs.xml >/dev/null
timeout 60 adb shell "mkdir -p /data/data/$PKG/shared_prefs && cp /data/local/tmp/prefs.xml /data/data/$PKG/shared_prefs/FlutterSharedPreferences.xml && chown $UID_APP:$UID_APP /data/data/$PKG/shared_prefs/FlutterSharedPreferences.xml && restorecon -R /data/data/$PKG/shared_prefs"
timeout 60 adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS
timeout 60 adb shell appops set "$PKG" SCHEDULE_EXACT_ALARM allow
timeout 60 adb logcat -c
launch; sleep 30
echo "process alive:"; alive
echo "=== adhan: alarms scheduled for the app (expect ~60)"
timeout 60 adb shell dumpsys alarm | grep -c "$PKG" || true
timeout 60 adb shell dumpsys alarm | grep -B1 -A3 "ScheduledNotificationReceiver" | head -14

# اضغط «تجربة الصوت»: مرّر الشاشة حتى يظهر الزر ثم المس مركزه.
find_bounds() { timeout 60 adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; timeout 60 adb shell cat /sdcard/ui.xml | python3 -c "
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
  timeout 60 adb shell input swipe 540 1900 540 500 300; sleep 1
done
echo "test button at: ${POS:-NOT FOUND}"
timeout 60 adb exec-out screencap -p > "$OUT/adhan_section.png"
if [ -n "$POS" ]; then
  timeout 60 adb shell input tap $POS; sleep 4
  echo "=== adhan: notification posted by the test button"
  timeout 60 adb shell dumpsys notification --noredact | grep -E "pkg=$PKG|channel=adhan|sound=|android.title|إيقاف|Stop" | head -20
  echo "=== adhan: channels"
  timeout 60 adb shell dumpsys notification | grep -A6 "adhan_full" | head -14
fi
timeout 60 adb exec-out screencap -p > "$OUT/adhan_after_test.png"
timeout 60 adb logcat -d > "$OUT/full2.log"
echo "=== adhan: crashes"; timeout 60 adb logcat -d -b crash | tail -30
