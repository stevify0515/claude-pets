#!/bin/bash
# Install the Claude Pets toolkit for the current user.
#   - /hatch-pet  : create a custom animated pet (skill)
#   - /pet        : toggle the floating desktop overlay (command)
# Safe to re-run (idempotent). macOS is required for the floating overlay;
# the /hatch-pet creation engine itself is cross-platform.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE="$HOME/.claude"
SKILL="$CLAUDE/skills/hatch-pet"
COMP="$CLAUDE/pets-companion"
CMDS="$CLAUDE/commands"
PETS="$CLAUDE/pets"
SETTINGS="$CLAUDE/settings.json"

echo "Installing Claude Pets…"

# 1) Skill engine + Python venv (Pillow) ------------------------------------
mkdir -p "$SKILL"
cp -R "$HERE/skills/hatch-pet/." "$SKILL/"
if command -v python3 >/dev/null 2>&1; then
  if [ ! -x "$SKILL/.venv/bin/python" ]; then
    echo "  • creating Python venv (Pillow)…"
    python3 -m venv "$SKILL/.venv"
  fi
  "$SKILL/.venv/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
  "$SKILL/.venv/bin/pip" install --quiet pillow >/dev/null 2>&1 || echo "  ! could not install Pillow; run: $SKILL/.venv/bin/pip install pillow"
else
  echo "  ! python3 not found — the hatch-pet engine needs Python 3."
fi

# 2) Companion overlay + scripts --------------------------------------------
mkdir -p "$COMP"
cp "$HERE/companion/"* "$COMP/"
chmod +x "$COMP/wake-pet" "$COMP/tuck-pet" "$COMP/toggle-pet" "$COMP/restart-pet" "$COMP/list-pets" "$COMP/set-active"
if [ "$(uname)" = "Darwin" ] && command -v swiftc >/dev/null 2>&1; then
  echo "  • building the macOS overlay…"
  swiftc -O "$COMP/duple_pet.swift" -o "$COMP/duple_pet" || echo "  ! overlay build failed"
else
  echo "  ! skipping overlay build (needs macOS + Xcode command line tools). /hatch-pet still works."
fi

# 3) /pet command ------------------------------------------------------------
mkdir -p "$CMDS"
cp "$HERE/commands/"*.md "$CMDS/"

# 4) Starter pets + active pointer ------------------------------------------
mkdir -p "$PETS/status"
for d in "$HERE/assets/pets/"*/; do
  name="$(basename "$d")"
  if [ ! -d "$PETS/$name" ]; then cp -R "$d" "$PETS/$name"; echo "  • installed starter pet: $name"; fi
done
# 4b) Personal pets (gitignored; present only on the owner's machines) ------
if [ -d "$HERE/personal-pets" ]; then
  for d in "$HERE/personal-pets/"*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ ! -d "$PETS/$name" ]; then cp -R "$d" "$PETS/$name"; echo "  • installed personal pet: $name"; fi
  done
fi
if [ ! -e "$PETS/active" ]; then
  first="$(ls -1 "$PETS" | grep -vx status | head -1)"
  [ -n "$first" ] && ln -sfn "$PETS/$first" "$PETS/active" && echo "  • active pet: $first"
fi

# 5) Status hooks in global settings.json -----------------------------------
HOOKCMD="python3 $COMP/pet_status.py"
python3 - "$SETTINGS" "$HOOKCMD" <<'PY'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except Exception: data = {}
hooks = data.get("hooks", {})
entry = [{"hooks": [{"type": "command", "command": cmd, "async": True}]}]
for ev in ["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop", "Notification", "SessionEnd"]:
    hooks[ev] = entry
data["hooks"] = hooks
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(data, open(path, "w"), indent=2)
print("  • wired status hooks into settings.json")
PY

echo ""
echo "✅ Installed. Restart Claude Code (or open /hooks once) so the new hooks load."
echo "   • /pets         → toggle the floating pet on/off"
echo "   • /pets choose  → switch between installed pets"
echo "   • /pets hatch   → create a custom pet with Claude Design (no API key)"
echo "   Try it now:  $COMP/wake-pet"
