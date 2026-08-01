#!/usr/bin/env bash
set -euo pipefail
export DISPLAY=:1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_artifacts_root.sh
source "$SCRIPT_DIR/_artifacts_root.sh"

OUT="$WODO_ARTIFACTS_ROOT/screenshots/pr-ui-gallery-real"
BASE="${WODO_WEB_URL:-http://127.0.0.1:8090}"
PROFILE="/tmp/wodo-real-gallery"
CLASS="WodoGalleryCapture"
mkdir -p "$OUT"

stop_chrome() {
  pkill -f "$PROFILE" 2>/dev/null || true
  pkill -f google-chrome 2>/dev/null || true
  sleep 1
}

stop_chrome
rm -f "$OUT"/*.png
rm -rf "$PROFILE"

CHROME=(
  google-chrome
  --no-sandbox
  --disable-service-workers
  --disable-features=LensOverlay,LensSearch,Translate
  --no-first-run
  --no-default-browser-check
  "--user-data-dir=$PROFILE"
  "--class=$CLASS"
)

shot_win() {
  local win=$1 name=$2
  rm -f "$OUT/$name"
  xdotool windowactivate "$win"
  sleep 0.3
  scrot -d 2 "$OUT/$name"
  echo "saved $name ($(stat -c%s "$OUT/$name") bytes)"
}

launch_demo() {
  local w=$1 h=$2 demo=$3 fresh=${4:-1}
  if [ "$fresh" = 1 ]; then
    stop_chrome
    rm -rf "$PROFILE"
  else
    stop_chrome
  fi
  "${CHROME[@]}" \
    --app="${BASE}/?wodo_demo=${demo}&t=$(date +%s)" \
    --window-size="${w},${h}" \
    --window-position=0,0 >/dev/null 2>&1 &
  sleep 14
  local win
  win=$(xdotool search --class "$CLASS" | head -1)
  xdotool windowactivate "$win"
  sleep 0.3
  echo "$win"
}

login_demo_user() {
  local win=$1
  xdotool mousemove --window "$win" 640 390 click 1
  sleep 0.2
  xdotool type --delay 8 --window "$win" --clearmodifiers "demo-screenshots@wodo.app"
  xdotool mousemove --window "$win" 640 470 click 1
  sleep 0.2
  xdotool type --delay 8 --window "$win" --clearmodifiers "DemoPass123!"
  xdotool mousemove --window "$win" 640 555 click 1
  sleep 4
  xdotool key --window "$win" Escape 2>/dev/null || true
  sleep 0.8
}

curl -sf -X POST http://127.0.0.1:3000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo-screenshots@wodo.app","password":"DemoPass123!"}' \
  >/dev/null 2>&1 || true

# ── Desktop (logged out) ─────────────────────────────────────────────────────
WIN=$(launch_demo 1280 900 home)
shot_win "$WIN" "01_home_desktop.png"

WIN=$(launch_demo 1280 900 login)
shot_win "$WIN" "02_login_desktop.png"

WIN=$(launch_demo 1280 900 qr)
sleep 5
shot_win "$WIN" "03_qr_pairing_desktop.png"

WIN=$(launch_demo 1280 900 register)
shot_win "$WIN" "04_register_desktop.png"

WIN=$(launch_demo 1280 900 settings)
shot_win "$WIN" "05_settings_logged_out_desktop.png"
for _ in $(seq 1 10); do xdotool click --window "$WIN" 4; done
sleep 0.5
shot_win "$WIN" "06_settings_scrolled_desktop.png"

# ── Mobile (logged out) ──────────────────────────────────────────────────────
WIN=$(launch_demo 390 844 home)
shot_win "$WIN" "07_home_mobile.png"

WIN=$(launch_demo 390 844 settings)
shot_win "$WIN" "08_settings_mobile.png"

WIN=$(launch_demo 390 844 login)
shot_win "$WIN" "09_login_mobile.png"

WIN=$(launch_demo 390 844 qr)
sleep 5
shot_win "$WIN" "10_qr_pairing_mobile.png"

WIN=$(launch_demo 390 844 register)
shot_win "$WIN" "11_register_mobile.png"

# ── Logged-in desktop (persist session in profile) ───────────────────────────
WIN=$(launch_demo 1280 900 login)
login_demo_user "$WIN"
shot_win "$WIN" "12_logged_in_home_desktop.png"

WIN=$(launch_demo 1280 900 settings 0)
shot_win "$WIN" "13_settings_logged_in_desktop.png"
for _ in $(seq 1 12); do xdotool click --window "$WIN" 4; done
sleep 0.5
shot_win "$WIN" "14_settings_security_desktop.png"

WIN=$(launch_demo 1280 900 approve-pairing 0)
shot_win "$WIN" "15_approve_pairing_desktop.png"

WIN=$(launch_demo 1280 900 linked-devices 0)
shot_win "$WIN" "16_linked_devices_desktop.png"

WIN=$(launch_demo 1280 900 protect-dialog 0)
shot_win "$WIN" "17_protect_dialog_desktop.png"

stop_chrome
echo "Done $OUT"
