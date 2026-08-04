# Shared artifact output root for capture/demo scripts.
# Source from other scripts: . "$(dirname "$0")/_artifacts_root.sh"
_wodo_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_wodo_repo_root="$(cd "$_wodo_script_dir/.." && pwd)"

if [[ -n "${WODO_ARTIFACTS_DIR:-}" ]]; then
  WODO_ARTIFACTS_ROOT="$WODO_ARTIFACTS_DIR"
elif [[ -d /opt/cursor/artifacts ]]; then
  WODO_ARTIFACTS_ROOT="/opt/cursor/artifacts"
else
  WODO_ARTIFACTS_ROOT="$_wodo_repo_root/artifacts"
fi

export WODO_ARTIFACTS_ROOT
