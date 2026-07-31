#!/usr/bin/env bash
# PR UI gallery — real Chrome (DISPLAY) + xdotool + scrot
set -euo pipefail

OUT="/opt/cursor/artifacts/screenshots/pr-ui-gallery"
URL="${WODO_WEB_URL:-http://127.0.0.1:8090}"
DISPLAY="${DISPLAY:-:1}"
export DISPLAY

PROFILE="/tmp/wodo-gallery-chrome"
mkdir -p "$OUT"
rm -rf "$PROFILE"

pkill -f "wodo-gallery-chrome" 2>/dev/null || true
pkill -f "wodo-chrome-final" 2>/dev/null || true
sleep 1

google-chrome \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-service-workers \
  --user-data-dir="${PROFILE}" \
  --disk-cache-size=1 \
  --window-size=1280,900 \
  --window-position=0,0 \
  --app="${URL}/?gallery=$(date +%s)" &
sleep 8

WIN=$(xdotool search --sync --onlyvisible --class Google-chrome | head -1)
xdotool windowactivate --sync "${WIN}"
sleep 1

shot() {
  xdotool windowactivate --sync "${WIN}"
  scrot -d 1 "${OUT}/$1.png"
  echo "saved $1.png"
}

click() {
  xdotool mousemove --window "${WIN}" "$1" "$2"
  sleep 0.1
  xdotool click 1
  sleep 1.3
}

# ── Desktop ─────────────────────────────────────────────────────────────────
shot "01_home_desktop"
click 140 200
shot "02_login_desktop"
click 640 635
sleep 5
shot "03_qr_pairing_desktop"
click 35 55
click 640 705
shot "04_register_desktop"
click 35 55
click 140 520
shot "05_settings_desktop"
for _ in 1 2 3 4 5 6; do xdotool click 4; done
sleep 0.4
shot "06_settings_scrolled_desktop"

# ── Mobile ────────────────────────────────────────────────────────────────────
xdotool windowsize "${WIN}" 390 844
sleep 2
xdotool windowactivate --sync "${WIN}"
sleep 1
click 195 450
sleep 2
shot "07_home_mobile"
click 350 55
shot "08_settings_mobile"
click 195 260
shot "09_login_mobile"
click 195 600
sleep 5
shot "10_qr_pairing_mobile"
click 30 55
click 195 690
shot "11_register_mobile"

# ── Security (desktop) ───────────────────────────────────────────────────────
xdotool windowsize "${WIN}" 1280 900
sleep 2
click 195 450
sleep 2
click 140 200
click 640 705
click 640 380
xdotool type --delay 8 --clearmodifiers "demo-screenshots@wodo.app"
click 640 460
xdotool type --delay 8 --clearmodifiers "DemoPass123!"
click 640 545
sleep 2
shot "12_logged_in_home_desktop"
click 140 520
shot "13_settings_logged_in_desktop"
for _ in 1 2 3 4 5 6 7 8; do xdotool click 4; done
sleep 0.4
shot "14_settings_security_desktop"
click 640 430
shot "15_approve_pairing_desktop"
click 35 55
click 140 520
click 640 500
sleep 2
shot "16_linked_devices_desktop"
click 35 55
click 140 520
for _ in 1 2 3 4 5 6 7 8; do xdotool click 4; done
click 640 570
sleep 1
shot "17_protect_dialog_desktop"

pkill -f "${PROFILE}" 2>/dev/null || true
echo "Gallery complete: ${OUT}"
