#!/usr/bin/env bash
# Graba un video real del flujo del PR: Chrome + wodo_demo + ffmpeg x11grab.
set -euo pipefail
export DISPLAY=:1
OUT="${1:-/opt/cursor/artifacts/wodo-pr25-demo.mp4}"
BASE="${WODO_WEB_URL:-http://127.0.0.1:8090}"
PROFILE="/tmp/wodo-video-demo"
CLASS="WodoVideoDemo"
W=1280
H=900

mkdir -p "$(dirname "$OUT")"
pkill -f "$PROFILE" 2>/dev/null || true
pkill -f google-chrome 2>/dev/null || true
sleep 2
rm -rf "$PROFILE"

curl -sf -X POST http://127.0.0.1:3000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo-screenshots@wodo.app","password":"DemoPass123!"}' \
  >/dev/null 2>&1 || true

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

pause() { sleep "${1:-4}"; }

launch() {
  local demo=$1
  pkill -f "$PROFILE" 2>/dev/null || true
  sleep 1
  "${CHROME[@]}" \
    --app="${BASE}/?wodo_demo=${demo}&t=$(date +%s)" \
    --window-size="${W},${H}" \
    --window-position=0,0 >/dev/null 2>&1 &
  sleep 12
  WIN=$(xdotool search --class "$CLASS" | head -1)
  xdotool windowactivate "$WIN" 2>/dev/null || true
  xdotool windowsize "$WIN" "$W" "$H" 2>/dev/null || true
  xdotool windowmove "$WIN" 0 0 2>/dev/null || true
}

click() {
  xdotool mousemove --window "$WIN" "$1" "$2"
  sleep 0.15
  xdotool click --window "$WIN" 1
  sleep 0.3
}

echo "Recording -> $OUT"
ffmpeg -y -loglevel warning \
  -f x11grab -draw_mouse 1 -framerate 24 \
  -video_size "${W}x${H}" -i "${DISPLAY}+0,0" \
  -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p \
  "$OUT" &
FFPID=$!
sleep 2

# 1. Home
launch home
pause 5

# 2. Login refactor
launch login
pause 6

# 3. QR pairing (API real)
launch qr
pause 8

# 4. Registro
launch register
pause 5

# 5. Ajustes
launch settings
pause 5
xdotool mousemove --window "$WIN" 980 420 click 1
for _ in $(seq 1 8); do xdotool click --window "$WIN" 4; done
pause 4

# 6. Login demo user (misma sesión)
launch login
pause 2
click 640 390
xdotool type --delay 10 --window "$WIN" --clearmodifiers "demo-screenshots@wodo.app"
click 640 470
xdotool type --delay 10 --window "$WIN" --clearmodifiers "DemoPass123!"
click 640 555
pause 5
xdotool key --window "$WIN" Escape 2>/dev/null || true
pause 4

# 7. Vincular dispositivo
pkill -f "$PROFILE" 2>/dev/null || true
sleep 1
"${CHROME[@]}" \
  --app="${BASE}/?wodo_demo=approve-pairing&t=$(date +%s)" \
  --window-size="${W},${H}" --window-position=0,0 >/dev/null 2>&1 &
sleep 12
WIN=$(xdotool search --class "$CLASS" | head -1)
pause 6

# 8. Diálogo proteger datos
launch protect-dialog
pause 6

kill -INT "$FFPID" 2>/dev/null || true
wait "$FFPID" 2>/dev/null || true

pkill -f "$PROFILE" 2>/dev/null || true
pkill -f google-chrome 2>/dev/null || true

ls -lh "$OUT"
echo "Done: $OUT"
