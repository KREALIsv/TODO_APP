#!/usr/bin/env bash
set -euo pipefail
export DISPLAY=:1
OUT=/opt/cursor/artifacts/screenshots/pr-ui-gallery-real
mkdir -p "$OUT"
pkill -f wodo-calibrate 2>/dev/null || true
rm -rf /tmp/wodo-calibrate
google-chrome --no-sandbox --disable-service-workers --user-data-dir=/tmp/wodo-calibrate --window-size=1280,900 --window-position=0,0 "http://127.0.0.1:8090/?v=$(date +%s)" &
sleep 12
WIN=$(xdotool search --sync --onlyvisible --class Google-chrome | head -1)
xdotool windowactivate --sync "$WIN"

for y in 220 235 250 265 280; do
  xdotool mousemove --window "$WIN" 130 "$y" click 1
  sleep 1.5
  scrot -d 1 "$OUT/_cal_login_y${y}.png"
  xdotool key Escape 2>/dev/null || true
  sleep 0.5
  xdotool key alt+Left 2>/dev/null || xdotool mousemove --window "$WIN" 35 55 click 1
  sleep 1
done

# settings path: Ajustes sidebar then login row in panel
xdotool mousemove --window "$WIN" 130 560 click 1
sleep 1.5
scrot -d 1 "$OUT/_cal_after_ajustes.png"
xdotool mousemove --window "$WIN" 980 320 click 1
sleep 1.5
scrot -d 1 "$OUT/_cal_after_ajustes_login_click.png"

ls -la "$OUT"/_cal_*.png
