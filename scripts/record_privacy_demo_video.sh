#!/usr/bin/env bash
# Video demo: Privacidad y seguridad + flujo E2EE (UI real en Chrome).
set -euo pipefail
export DISPLAY=:1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_artifacts_root.sh
source "$SCRIPT_DIR/_artifacts_root.sh"

OUT="${1:-$WODO_ARTIFACTS_ROOT/wodo-privacidad-seguridad-demo.mp4}"
BASE="${WODO_WEB_URL:-http://127.0.0.1:8090}"
PROFILE="/tmp/wodo-privacy-video"
CLASS="WodoPrivacyDemo"
W=1280
H=900

mkdir -p "$(dirname "$OUT")"
pkill -f "$PROFILE" 2>/dev/null || true
pkill -f google-chrome 2>/dev/null || true
sleep 2
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

pause() { sleep "${1:-4}"; }

launch() {
  local demo=$1
  pkill -f "$PROFILE" 2>/dev/null || true
  sleep 1
  "${CHROME[@]}" \
    --app="${BASE}/?wodo_demo=${demo}&t=$(date +%s)" \
    --window-size="${W},${H}" \
    --window-position=0,0 >/dev/null 2>&1 &
  sleep 14
  WIN=$(xdotool search --class "$CLASS" | head -1)
  xdotool windowactivate "$WIN" 2>/dev/null || true
  xdotool windowsize "$WIN" "$W" "$H" 2>/dev/null || true
  xdotool windowmove "$WIN" 0 0 2>/dev/null || true
}

click() {
  xdotool mousemove --window "$WIN" "$1" "$2"
  sleep 0.2
  xdotool click --window "$WIN" 1
  sleep 0.35
}

scroll_down() {
  for _ in $(seq 1 "${1:-6}"); do
    xdotool click --window "$WIN" 4
    sleep 0.15
  done
}

echo "Recording -> $OUT"
ffmpeg -y -loglevel warning \
  -f x11grab -draw_mouse 1 -framerate 24 \
  -video_size "${W}x${H}" -i "${DISPLAY}+0,0" \
  -c:v libx264 -preset ultrafast -crf 21 -pix_fmt yuv420p \
  "$OUT" &
FFPID=$!
sleep 2

# 1. Ajustes — sección Privacidad (sin sesión)
launch settings
pause 3
scroll_down 6
pause 5

# 2. Pantalla Privacidad y seguridad (modo local)
launch privacy-security
pause 7

# 3. Login (refactor UI)
launch login
pause 6

# 4. QR pairing
launch qr
pause 8

# 5. Volver a Ajustes y abrir Privacidad manualmente (click fila ~y=520 en panel)
launch settings
pause 2
click 1180 520
pause 6

# 6. Login con cuenta demo (API producción)
launch login
pause 2
click 640 400
xdotool type --delay 12 --window "$WIN" --clearmodifiers "demo-screenshots@wodo.app"
click 640 480
xdotool type --delay 12 --window "$WIN" --clearmodifiers "DemoPass123!"
click 640 565
pause 6
xdotool key --window "$WIN" Escape 2>/dev/null || true
pause 3

# 7. Privacidad logueado — activar E2EE (modal)
launch protect-dialog
pause 8
# Cerrar modal sin activar (Escape)
xdotool key --window "$WIN" Escape 2>/dev/null || true
pause 2

# 8. Vincular dispositivo
launch approve-pairing
pause 6

# 9. Dispositivos vinculados
launch linked-devices
pause 5

kill -INT "$FFPID" 2>/dev/null || true
wait "$FFPID" 2>/dev/null || true

pkill -f "$PROFILE" 2>/dev/null || true

# Recorte inicial (arranque ffmpeg)
TRIM="${OUT%.mp4}-trimmed.mp4"
ffmpeg -y -loglevel warning -ss 2 -i "$OUT" -c copy "$TRIM" 2>/dev/null || cp "$OUT" "$TRIM"

ls -lh "$OUT" "$TRIM"
echo "Done: $TRIM"
