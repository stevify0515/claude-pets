#!/bin/bash
# Remove the Claude Pets toolkit for the current user.
set -e
CLAUDE="$HOME/.claude"
COMP="$CLAUDE/pets-companion"

"$COMP/tuck-pet" >/dev/null 2>&1 || pkill -f duple_pet 2>/dev/null || true

rm -rf "$CLAUDE/skills/hatch-pet"
rm -rf "$COMP"
rm -f "$CLAUDE/commands/pet.md"

# Remove our status hooks (leave any other hooks intact).
python3 - "$CLAUDE/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
if not os.path.exists(path): sys.exit(0)
try: data = json.load(open(path))
except Exception: sys.exit(0)
hooks = data.get("hooks", {})
def is_ours(group):
    return any(h.get("command","").endswith("pets-companion/pet_status.py")
              for item in group for h in item.get("hooks", []))
for ev in list(hooks.keys()):
    if is_ours(hooks[ev]): del hooks[ev]
if hooks: data["hooks"] = hooks
else: data.pop("hooks", None)
json.dump(data, open(path, "w"), indent=2)
print("removed status hooks")
PY

echo "Uninstalled. Your hatched pets under ~/.claude/pets/ were left in place (delete manually if you want)."
