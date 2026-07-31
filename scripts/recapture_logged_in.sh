#!/usr/bin/env bash
set -euo pipefail
export DISPLAY=:1
OUT=/opt/cursor/artifacts/screenshots/pr-ui-gallery-real
BASE=http://127.0.0.1:8090
PROFILE=/tmp/wodo-loggedin-fix
CLASS=WodoLoggedInFix

stop() { pkill -f "$PROFILE" 2>/dev/null || true; sleep 1; }

stop
rm -rf "$PROFILE"

google-chrome --no-sandbox --disable-service-workers --disable-features=LensOverlay,LensSearch \
  --user-data-dir="$PROFILE" --class="$CLASS" \
  --app="${BASE}/?wodo_demo=login&t=1" --window-size=1280,900 --window-position=0,0 >/dev/null 2>&1 &
sleep 14
WIN=$(xdotool search --class "$CLASS" | head -1)
xdotool windowactivate "$WIN"

xdotool mousemove --window "$WIN" 640 390 click 1; sleep 0.2
xdotool type --delay 8 --window "$WIN" --clearmodifiers "demo-screenshots@wodo.app"
xdotool mousemove --window "$WIN" 640 470 click 1; sleep 0.2
xdotool type --delay 8 --window "$WIN" --clearmodifiers "DemoPass123!"
xdotool mousemove --window "$WIN" 640 555 click 1; sleep 4
xdotool key --window "$WIN" Escape 2>/dev/null || true
sleep 2

stop
sleep 2

google-chrome --no-sandbox --disable-service-workers --disable-features=LensOverlay,LensSearch \
  --user-data-dir="$PROFILE" --class="$CLASS" \
  --app="${BASE}/?wodo_demo=settings&t=2" --window-size=1280,900 --window-position=0,0 >/dev/null 2>&1 &
sleep 16
WIN=$(xdotool search --class "$CLASS" | head -1)
xdotool windowactivate "$WIN"
sleep 2

rm -f "$OUT/13_settings_logged_in_desktop.png"
scrot -d 2 "$OUT/13_settings_logged_in_desktop.png"

xdotool mousemove --window "$WIN" 980 420 click 1
for _ in $(seq 1 8); do xdotool click --window "$WIN" 4; done
sleep 0.5
rm -f "$OUT/14_settings_security_desktop.png"
scrot -d 2 "$OUT/14_settings_security_desktop.png"

stop
sleep 1
google-chrome --no-sandbox --disable-service-workers --disable-features=LensOverlay,LensSearch \
  --user-data-dir="$PROFILE" --class="$CLASS" \
  --app="${BASE}/?wodo_demo=linked-devices&t=3" --window-size=1280,900 --window-position=0,0 >/dev/null 2>&1 &
sleep 16
WIN=$(xdotool search --class "$CLASS" | head -1)
rm -f "$OUT/16_linked_devices_desktop.png"
scrot -d 2 "$OUT/16_linked_devices_desktop.png"

ls -lh "$OUT/13_settings_logged_in_desktop.png" "$OUT/14_settings_security_desktop.png" "$OUT/16_linked_devices_desktop.png"
stop
echo DONE
