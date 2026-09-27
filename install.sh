#!/usr/bin/env bash
# Install the /orch skill for Claude Code.
#   curl -fsSL https://raw.githubusercontent.com/legifx/orch/main/install.sh | bash
set -euo pipefail
REPO="${ORCH_REPO:-https://github.com/legifx/orch.git}"
DEST="${ORCH_DEST:-$HOME/.claude/skills/orch}"
BIN_DIR="${ORCH_BIN_DIR:-$HOME/.local/bin}"

command -v git >/dev/null || { echo "orch: git is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "orch: python3 (3.9+) is required" >&2; exit 1; }
python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' || { echo "orch: python3 >= 3.9 required" >&2; exit 1; }

if [ -d "$DEST/.git" ]; then
  echo "updating $DEST"; git -C "$DEST" pull --ff-only --quiet
elif [ -e "$DEST" ]; then
  echo "orch: $DEST exists and is not a git checkout - move it away first" >&2; exit 1
else
  mkdir -p "$(dirname "$DEST")"; git clone --depth 1 --quiet "$REPO" "$DEST"
fi
chmod +x "$DEST/bin/orch"
mkdir -p "$BIN_DIR"
ln -sfn "$DEST/bin/orch" "$BIN_DIR/orch"

echo "installed: skill $DEST, cli $BIN_DIR/orch"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "note: add $BIN_DIR to PATH (the skill falls back to the full path otherwise)";; esac
echo
"$DEST/bin/orch" detect || true
echo
echo "Restart Claude Code (or start a new session), then type /orch"
