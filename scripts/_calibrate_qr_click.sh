#!/usr/bin/env bash
set -uo pipefail
export DISPLAY=:1
OUT=/opt/cursor/artifacts/screenshots/pr-ui-gallery-real
mkdir -p "$OUT"
pkill -f wodo-cal-qr 2>/dev/null || true
pkill -f google-chrome 2>/dev/null || true
sleep 2
rm -rf /tmp/wodo-cal-qr

google-chrome --no-sandbox --disable-service-workers \
  --disable-features=LensOverlay,LensSearch \
  --user-data-dir=/tmp/wodo-cal-qr --class=WodoCalQR \
  --app="http://127.0.0.1:8090/?t=$(date +%s)" \
  --window-size=1280,900 --window-position=0,0 &
sleep 16

WIN=$(xdotool search --sync --class WodoCalQR | head -1)
echo "WIN=$WIN"
xdotool windowactivate --sync "$WIN"

click() {
  xdotool mousemove --window "$WIN" --sync "$1" "$2"
  sleep 0.15
  xdotool click --window "$WIN" 1
  sleep 2.5
}

click 130 250
scrot -u -d 1 "$OUT/_cal_before_qr.png"

for y in 660 680 695 710 730; do
  click 640 "$y"
  scrot -u -d 1 "$OUT/_cal_qr_y${y}.png"
  xdotool key --window "$WIN" Escape 2>/dev/null || true
  sleep 0.5
  click 130 250
done

ls -lh "$OUT"/_cal_qr_*.png "$OUT"/_cal_before_qr.png
pkill -f wodo-cal-qr 2>/dev/null || true
