# Claude Pets — Final Shippable v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `claude-pets/` as a self-contained, API-key-free toolkit: one `/pets` command surface, 5 bundled animated starter pets, a personal (gitignored) Duple pet, a Claude-Design hatch pipeline, and a private GitHub repo.

**Architecture:** `claude-pets/` is the distributable. `install.sh` copies a skill engine, a macOS overlay, `/pets` commands, and bundled pets into `~/.claude/`. Pets are full 8×9 sprite atlases built from a single sprite by deterministic Pillow transforms (`compose_simple_pet.py`) — no image API. Public starters live in committed `assets/pets/`; the owner's Duple lives in gitignored `personal-pets/`.

**Tech Stack:** Bash, Python 3 + Pillow, Swift (overlay, unchanged), Claude Code slash commands + skills, git + `gh`.

**Domain note on "tests":** This is shell/asset/packaging work, not unit-testable library code. "Verification" steps replace pytest: atlas dimension checks, a fresh-`HOME` install smoke test, and visual contact-sheet review. These are the real acceptance gates.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `tools/build_starters.py` | Flatten each transparent starter onto a chroma, run the composer, write `assets/pets/<id>/` | Create |
| `assets/pets/<id>/{pet.json,spritesheet.webp}` | 5 bundled animated starter packages | Create (generated) |
| `commands/pets.md` | `/pets` dispatcher (toggle/list/choose/hatch) | Create |
| `commands/pet.md` | `/pet` toggle alias | Keep as-is |
| `companion/list-pets` | Print installed pets, mark active | Create |
| `companion/set-active` | Repoint `active` + restart overlay | Create |
| `personal-pets/duple/{pet.json,spritesheet.webp}` | Owner's personal pet (gitignored) | Create (copied) |
| `skills/hatch-pet/SKILL.md` | Rewritten Claude-Design pipeline, no OpenAI | Modify |
| `skills/hatch-pet/references/claude-design-prompt.md` | Paste-ready Claude Design prompt template | Create |
| `install.sh` | Copy `*.md` commands, chmod new scripts, install personal pets, drop OpenAI text | Modify |
| `README.md` | New `/pets` table, Claude Design flow, no-OpenAI, Duple note | Modify |
| `.gitignore` | Exclude `personal-pets/`, `.DS_Store`, venvs, tmp | Create |
| `duple-pet.zip` | Transfer artifact for the work laptop | Create (built) |

---

## Task 1: Build tooling — a Pillow venv for asset building

**Files:**
- Create: `tools/.venv/` (gitignored, local build only)

- [ ] **Step 1: Create a build venv with Pillow**

Run:
```bash
cd /Users/stevenle/claude-pets
python3 -m venv tools/.venv
tools/.venv/bin/pip install --quiet --upgrade pip
tools/.venv/bin/pip install --quiet pillow
```

- [ ] **Step 2: Verify Pillow is importable**

Run: `tools/.venv/bin/python -c "import PIL, PIL.Image; print('pillow', PIL.__version__)"`
Expected: prints `pillow <version>` with no traceback.

---

## Task 2: Build the 5 starter animated packages

**Files:**
- Create: `tools/build_starters.py`
- Create (generated): `assets/pets/{biscuit,bloop,ember,mochi,sprout}/{pet.json,spritesheet.webp}`

- [ ] **Step 1: Write the build script**

Create `tools/build_starters.py`:
```python
#!/usr/bin/env python3
"""Build the 5 bundled starter pets from transparent FINAL sprites.

Each FINAL sprite is a transparent PNG. compose_simple_pet.py keys out a *solid*
background (auto-detected from the border ring), so we first flatten each sprite
onto a saturated chroma far from its palette AND far from the dark house outline.
The composer then removes that flat fill and animates the sprite into a full 8x9
atlas — no image API.
"""
import subprocess, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "FINAL" / "sprites"
OUT = ROOT / "assets" / "pets"
COMPOSE = ROOT / "skills" / "hatch-pet" / "scripts" / "compose_simple_pet.py"
PY = sys.executable

# id -> (display name, one-line description, chroma far from the pet's colors)
PETS = {
    "biscuit": ("Biscuit", "A warm, loyal companion for steady focused work.", "#00FF00"),
    "bloop":   ("Bloop", "A bouncy blue blob that keeps you company.", "#FF00FF"),
    "ember":   ("Ember", "A tiny fire spirit that glows while you build.", "#00FF00"),
    "mochi":   ("Mochi", "A soft, squishy friend for calm sessions.", "#00FF00"),
    "sprout":  ("Sprout", "A little green sprout that grows alongside your work.", "#FF00FF"),
}


def flatten(src: Path, chroma: str, dst: Path) -> None:
    img = Image.open(src).convert("RGBA")
    r = int(chroma[1:3], 16); g = int(chroma[3:5], 16); b = int(chroma[5:7], 16)
    bg = Image.new("RGBA", img.size, (r, g, b, 255))
    bg.alpha_composite(img)
    dst.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(dst)


def main() -> None:
    tmp = ROOT / "tools" / "_flattened"
    tmp.mkdir(parents=True, exist_ok=True)
    for pid, (name, desc, chroma) in PETS.items():
        src = SPRITES / f"{pid}-256.png"
        flat = tmp / f"{pid}.png"
        flatten(src, chroma, flat)
        subprocess.run([
            PY, str(COMPOSE), "--base", str(flat), "--chroma", chroma,
            "--id", pid, "--name", name, "--description", desc,
            "--out-dir", str(OUT / pid),
        ], check=True)
        print(f"built {pid}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the build**

Run:
```bash
cd /Users/stevenle/claude-pets
tools/.venv/bin/python tools/build_starters.py
```
Expected: prints `built biscuit` … `built sprout`, no traceback.

- [ ] **Step 3: Verify each atlas has the correct dimensions and pet.json**

Run:
```bash
cd /Users/stevenle/claude-pets
for p in biscuit bloop ember mochi sprout; do
  echo -n "$p "; sips -g pixelWidth -g pixelHeight "assets/pets/$p/spritesheet.webp" 2>/dev/null | grep pixel | tr '\n' ' '
  test -f "assets/pets/$p/pet.json" && echo "json:ok" || echo "json:MISSING"
done
```
Expected: every line shows `pixelWidth: 1536 pixelHeight: 1872 json:ok`.

- [ ] **Step 4: Visual review — generate a contact sheet per pet and look at it**

Run:
```bash
cd /Users/stevenle/claude-pets
for p in biscuit bloop ember mochi sprout; do
  tools/.venv/bin/python -c "from PIL import Image; Image.open('assets/pets/$p/spritesheet.webp').convert('RGBA').save('tools/_check_$p.png')"
done
```
Then open `tools/_check_*.png` and confirm for each: sprite fully opaque, **no chroma halo**, **dark outline intact** (not eaten), centered in each cell.
Acceptance: if any pet shows a colored halo or a chewed outline, change its chroma in `PETS` (pick a color absent from that pet — e.g. swap `#00FF00`↔`#FF00FF`, or use `#0000FF`) and re-run Steps 2–4.

- [ ] **Step 5: Refresh the FINAL showcase HTML**

Read `FINAL/Claude Pets - Collection.html`, then update it so it lists all 5 pets and points at the built `assets/pets/<id>/spritesheet.webp` (or embeds the `tools/_check_<id>.png` previews). Keep it a static, dependency-free single file. Confirm it opens in a browser and shows all 5.

- [ ] **Step 6: Commit (deferred)**

Note: the repo is initialized in Task 7. Do not commit yet; leave changes staged-in-working-tree. (All earlier "commit" gates in this plan are folded into Task 7's single initial commit because the repo does not exist until then.)

---

## Task 3: `/pets` command surface + switch helpers

**Files:**
- Create: `companion/list-pets`
- Create: `companion/set-active`
- Create: `commands/pets.md`

- [ ] **Step 1: Write `companion/list-pets`**

Create `companion/list-pets`:
```bash
#!/bin/bash
# List installed pets, marking the active one. Backs `/pets list` and `/pets choose`.
PETS="$HOME/.claude/pets"
active=""
[ -L "$PETS/active" ] && active="$(basename "$(readlink "$PETS/active")")"
shopt -s nullglob
for d in "$PETS"/*/; do
  name="$(basename "$d")"
  [ "$name" = "status" ] && continue
  [ "$name" = "active" ] && continue
  disp="$name"
  if [ -f "$d/pet.json" ]; then
    dn="$(python3 -c "import json;print(json.load(open('$d/pet.json')).get('displayName',''))" 2>/dev/null)"
    [ -n "$dn" ] && disp="$dn"
  fi
  if [ "$name" = "$active" ]; then echo "* $name — $disp (active)"; else echo "  $name — $disp"; fi
done
```

- [ ] **Step 2: Write `companion/set-active`**

Create `companion/set-active`:
```bash
#!/bin/bash
# Point the active pet at <id> and reload the overlay. Backs `/pets choose`.
set -e
PETS="$HOME/.claude/pets"
COMP="$HOME/.claude/pets-companion"
id="$1"
[ -z "$id" ] && { echo "usage: set-active <pet-id>" >&2; exit 2; }
[ -d "$PETS/$id" ] || { echo "No such pet: $id" >&2; exit 1; }
ln -sfn "$PETS/$id" "$PETS/active"
"$COMP/restart-pet" >/dev/null 2>&1 || true
echo "Active pet is now: $id"
```

- [ ] **Step 3: Write `commands/pets.md`**

Create `commands/pets.md`:
```markdown
---
description: Manage the floating desktop pet — toggle, choose, list, or hatch a new one
allowed-tools: Bash(~/.claude/pets-companion/toggle-pet:*), Bash(~/.claude/pets-companion/list-pets:*), Bash(~/.claude/pets-companion/set-active:*)
---

Dispatch on the argument in `$ARGUMENTS`:

- **empty** (just `/pets`): run `~/.claude/pets-companion/toggle-pet` and report in one short line whether the pet woke up or was tucked away. Nothing else.
- **`list`**: run `~/.claude/pets-companion/list-pets` and show its output as-is.
- **`choose`**: run `~/.claude/pets-companion/list-pets`, show the user the pets, and ask which they want. When they answer, run `~/.claude/pets-companion/set-active <id>` using the **id** (the first column, not the display name), then confirm in one line.
- **`hatch`**: invoke the `hatch-pet` skill and follow it to create a new pet.

Do not explain the pet system unless asked.
```

- [ ] **Step 4: Verify the helper scripts run against the current install**

Run:
```bash
chmod +x /Users/stevenle/claude-pets/companion/list-pets /Users/stevenle/claude-pets/companion/set-active
cp /Users/stevenle/claude-pets/companion/list-pets /Users/stevenle/claude-pets/companion/set-active "$HOME/.claude/pets-companion/" 2>/dev/null || true
"$HOME/.claude/pets-companion/list-pets"
```
Expected: prints the currently-installed pets with one marked `(active)`. (If `~/.claude/pets-companion` does not exist yet on this machine, defer this check to the Task 8 smoke test.)

---

## Task 4: Personal Duple pet (gitignored) + install wiring

**Files:**
- Create: `personal-pets/duple/{pet.json,spritesheet.webp}` (copied from the duple repo)
- Modify: `install.sh`

- [ ] **Step 1: Copy the built Duple into personal-pets**

Run:
```bash
mkdir -p /Users/stevenle/claude-pets/personal-pets/duple
cp /Users/stevenle/duple/assets/pets/duple/pet.json /Users/stevenle/duple/assets/pets/duple/spritesheet.webp \
   /Users/stevenle/claude-pets/personal-pets/duple/
```
Verify: `ls /Users/stevenle/claude-pets/personal-pets/duple/` shows both files.

- [ ] **Step 2: Update `install.sh` — copy all command files**

In `install.sh`, replace the single command copy:
```bash
cp "$HERE/commands/pet.md" "$CMDS/pet.md"
```
with:
```bash
cp "$HERE/commands/"*.md "$CMDS/"
```

- [ ] **Step 3: Update `install.sh` — chmod the new helper scripts**

In `install.sh`, change the chmod line to include the new scripts:
```bash
chmod +x "$COMP/wake-pet" "$COMP/tuck-pet" "$COMP/toggle-pet" "$COMP/restart-pet" "$COMP/list-pets" "$COMP/set-active"
```

- [ ] **Step 4: Update `install.sh` — install personal pets if present**

Immediately after the existing `assets/pets` starter loop (the `for d in "$HERE/assets/pets/"*/; do … done` block), add:
```bash
# 4b) Personal pets (gitignored; present only on the owner's machines) ------
if [ -d "$HERE/personal-pets" ]; then
  for d in "$HERE/personal-pets/"*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ ! -d "$PETS/$name" ]; then cp -R "$d" "$PETS/$name"; echo "  • installed personal pet: $name"; fi
  done
fi
```

- [ ] **Step 5: Update `install.sh` — drop the OpenAI line from final output**

In the closing `echo` block, change:
```bash
echo "   • /hatch-pet   → create a custom pet (set OPENAI_API_KEY to generate art)"
```
to:
```bash
echo "   • /pets choose → switch between installed pets"
echo "   • /pets hatch  → create a custom pet with Claude Design (no API key)"
```

- [ ] **Step 6: Verify install.sh still parses**

Run: `bash -n /Users/stevenle/claude-pets/install.sh`
Expected: no output (syntax OK).

---

## Task 5: Hatch pipeline rewrite — Claude Design, zero OpenAI

**Files:**
- Create: `skills/hatch-pet/references/claude-design-prompt.md`
- Modify: `skills/hatch-pet/SKILL.md`

- [ ] **Step 1: Write the Claude Design prompt template**

Create `skills/hatch-pet/references/claude-design-prompt.md`:
```markdown
# Claude Design prompt template

Hand this to the user to paste into Claude Design (desktop / claude.ai). Fill the
[BRACKETS] from the agreed concept. Tell the user they can freely edit wording,
colors, and accessories — but must keep the **bold technical constraints**, or the
animator can't key the background cleanly.

---
Create a **single pixel-art sprite** of [PET CONCEPT: e.g. "a small round fire
spirit with big friendly eyes"].

Style: 8-bit / pixel-art mascot. Compact chibi proportions, chunky readable
silhouette, **thick dark 1–2px outline**, limited palette, flat cel shading, simple
expressive face, tiny limbs. No painterly/3D/glossy/anime rendering, no soft
gradients, no fine detail that would vanish when shrunk to ~190px.

Palette: [PALETTE]. Accessory / motif: [MOTIF].

**Technical (keep exactly):**
- **One** centered, full-body sprite — facing forward, standing/neutral pose.
- **Solid flat background, color [CHROMA — a saturated color far from the pet's
  palette, e.g. bright green #00FF00 or magenta #FF00FF]. No transparency, no
  gradient, no scenery, no shadow on the ground.**
- Sprite fully inside frame with a little padding; not cropped at the edges.
- Square-ish image, roughly 1024×1024.

Save it as a PNG and give me the file path.
---
```

- [ ] **Step 2: Rewrite `SKILL.md` Step 2 and Step 3**

In `skills/hatch-pet/SKILL.md`:

Replace the frontmatter `description:` line so it no longer mentions OpenAI. New value:
```
description: Create a custom animated desktop pet companion (Codex /pets-style) — an 8x9 pixel-art sprite atlas with idle/wave/jump/run animations, packaged and made the active pet for the floating overlay. Use when the user runs /pets hatch or /hatch-pet, wants to make/hatch a pet, create a mascot for a repo, or design a companion from their interests. Infers a pet concept from the repo's vibe OR the user's interests, confirms direction, hands the user a Claude Design prompt to generate one sprite, then animates it into a full atlas with bundled deterministic scripts — no image API key required.
```

Replace the **Environment** note line:
```
Run every script with `$PY`. Generating artwork needs `OPENAI_API_KEY` + `curl`; preview videos need `ffmpeg`.
```
with:
```
Run every script with `$PY`. Artwork comes from Claude Design (the user generates one sprite); preview videos need `ffmpeg` (optional).
```

Replace the entire **`## Step 2 — Generate the artwork`** section (through the end of the gpt-image `generate_pet_images.py` base instructions, up to the start of `## Step 3`) with:
```
## Step 2 — Get the base sprite from Claude Design

Claude can't generate images, so the user makes the one base sprite in **Claude
Design** (desktop app / claude.ai). Open `references/claude-design-prompt.md`, fill
the [BRACKETS] from the agreed concept, and hand the user the finished prompt. Tell
them: paste it into Claude Design, tweak the look however they like, but keep the
**solid-background** and **dark-outline** constraints, then save the PNG and give you
the file path.

Pick the **chroma** you put in the prompt to contrast the pet: green `#00FF00` for
warm/red/golden pets, magenta `#FF00FF` for green/blue/cool pets. Remember which one
you told them to use — you pass the same value to the composer below.

When the user returns a path, **inspect it**: it should be one crisp, fully-visible
pixel-art sprite on a flat background. If it's blurry, cropped, or the background
isn't solid, ask them to regenerate with the constraints kept.
```

Replace the **`## Step 3`** opening (the "Recommended: reliable single-sprite path" block) so the single-sprite composer path is the *only* documented path. Keep the existing `compose_simple_pet.py` invocation exactly, but update the surrounding prose to:
```
## Step 3 — Animate the sprite and install it

Turn the one Claude Design sprite into a full animated atlas (idle breathe, jump,
lean, wave-tilt, etc.) with deterministic transforms — no extra tools, no API calls,
never empty/garbled frames:

```bash
$PY "$SKILL_DIR/scripts/compose_simple_pet.py" --base /path/to/their-sprite.png \
  --chroma "<#RRGGBB you told them to use>" --id <id> --name "<Name>" \
  --description "<one sentence>" --out-dir "$PETS/<id>"
```

This auto-keys the background and writes `$PETS/<id>/{pet.json, spritesheet.webp}`.
Confirm it looks clean (no background halo; sprite fully opaque). If the pet looks
faded/eaten, the background wasn't contrasting enough — ask the user to regenerate the
sprite on a more contrasting solid color and recompose.
```

Delete the **"Optional: full multi-pose animation (advanced, more API calls)"** subsection and its code block entirely.

Update the **Rules** list: remove the two rules that mandate gpt-image
("Generate every visual job with gpt-image; never substitute…" and "Only the base job
may be prompt-only…"). Keep the geometry/atlas and identity-drift rules. Add:
```
- The base sprite always comes from Claude Design on a solid background; never fabricate sprites locally.
```

- [ ] **Step 3: Verify no OpenAI references remain in the skill**

Run: `grep -rin "openai\|gpt-image\|OPENAI_API_KEY" /Users/stevenle/claude-pets/skills/hatch-pet/SKILL.md`
Expected: no matches. (Legacy script files may still reference it — that's fine; only `SKILL.md` must be clean.)

---

## Task 6: README + .gitignore + transfer artifact

**Files:**
- Create: `.gitignore`
- Modify: `README.md`
- Create (built): `duple-pet.zip`

- [ ] **Step 1: Write `.gitignore`**

Create `.gitignore`:
```gitignore
.DS_Store
**/.DS_Store
personal-pets/
tools/.venv/
tools/_flattened/
tools/_check_*.png
**/.venv/
/tmp/
duple-pet.zip
```

- [ ] **Step 2: Update `README.md`**

In `README.md`:
- Replace the "Two slash commands" list with the `/pets` table (toggle / `/pets choose` / `/pets list` / `/pets hatch`), noting `/pet` and `/hatch-pet` still work as aliases.
- In **Requirements**, delete the `OPENAI_API_KEY` bullet. Replace with: "**Claude Design** (desktop or claude.ai) to generate a new pet's sprite when you `/pets hatch`. No API keys."
- In **Using it → Create**, describe the new flow: Claude hands you a Claude Design prompt → you generate one sprite → Claude animates it into a full atlas.
- In **Switch pets**, replace the manual `ln -sfn` instructions with `/pets choose`.
- In **Notes**, change the "bundled starter pet (Duple)" line to: "Five starter pets (Biscuit, Bloop, Ember, Mochi, Sprout) ship ready to use. Duple is the owner's personal pet and is not included in the shared repo."

- [ ] **Step 3: Build the Duple transfer artifact**

Run:
```bash
cd /Users/stevenle/claude-pets
ditto -c -k --sequesterRsrc personal-pets/duple duple-pet.zip
unzip -l duple-pet.zip | grep -E 'pet.json|spritesheet.webp'
```
Expected: the listing shows both `pet.json` and `spritesheet.webp`.

---

## Task 7: Initialize repo, commit, push to private GitHub

**Files:**
- Create: `.git/` (repo)

- [ ] **Step 1: Initialize and stage**

Run:
```bash
cd /Users/stevenle/claude-pets
git init
git add -A
git status --short
```
Expected: `personal-pets/`, `tools/.venv/`, `tools/_flattened/`, `tools/_check_*.png`, `.DS_Store`, `duple-pet.zip` are **absent** from the staged list (gitignored). `assets/pets/<id>/` files, `commands/pets.md`, `companion/list-pets`, `companion/set-active`, the rewritten skill, README, `.gitignore`, and the docs are present.

- [ ] **Step 2: Verify Duple is not tracked**

Run: `git ls-files | grep -i duple || echo "duple not tracked — good"`
Expected: prints `duple not tracked — good` (no `personal-pets/duple/...` paths).

- [ ] **Step 3: Initial commit**

Run:
```bash
cd /Users/stevenle/claude-pets
git commit -m "$(cat <<'EOF'
feat: Claude Pets v1 — unified /pets, 5 animated starters, Claude Design hatch

- /pets command surface (toggle/list/choose/hatch); /pet + /hatch-pet aliases
- 5 bundled starter pets built from FINAL sprites (no image API)
- hatch pipeline rewritten for Claude Design; OpenAI requirement removed
- personal Duple kept out of the repo via .gitignore

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Create the private GitHub repo and push**

Run:
```bash
cd /Users/stevenle/claude-pets
gh auth status   # confirm authenticated first
gh repo create claude-pets --private --source=. --remote=origin --push
```
Expected: repo created and pushed. If `gh` is not authenticated, stop and tell the user to run `! gh auth login` in the session, then re-run this step.

---

## Task 8: Full smoke test in an isolated HOME

**Files:** none (verification only)

- [ ] **Step 1: Install into a throwaway HOME from a clean clone**

Run:
```bash
TMPHOME="$(mktemp -d)"
TMPCLONE="$(mktemp -d)"
git clone /Users/stevenle/claude-pets "$TMPCLONE/claude-pets"
cd "$TMPCLONE/claude-pets"
HOME="$TMPHOME" bash install.sh
```
Expected: installer reports installing 5 starter pets (`biscuit`…`sprout`), wiring hooks, and an `active` pet. It must **not** mention `duple` (gitignored, absent from the clone) and **not** mention `OPENAI_API_KEY`.

- [ ] **Step 2: Verify installed contents**

Run:
```bash
ls "$TMPHOME/.claude/pets"
ls "$TMPHOME/.claude/commands"
HOME="$TMPHOME" "$TMPHOME/.claude/pets-companion/list-pets"
```
Expected: `pets/` holds the 5 starters + `active` + `status`, no `duple`. `commands/` holds `pets.md` and `pet.md`. `list-pets` prints the 5 pets with one active.

- [ ] **Step 3: Verify a colleague gets no API-key prompt and Duple is absent**

Run: `grep -rin "OPENAI\|gpt-image" "$TMPCLONE/claude-pets/README.md" "$TMPCLONE/claude-pets/skills/hatch-pet/SKILL.md" || echo "clean — no openai in user-facing docs"`
Expected: prints `clean — no openai in user-facing docs`.

- [ ] **Step 4: Clean up**

Run: `rm -rf "$TMPHOME" "$TMPCLONE"`

---

## Task 9: Update memory

**Files:** memory store (outside the repo)

- [ ] **Step 1: Update the Claude Pets memory entry**

Update `/Users/stevenle/.claude/projects/-Users-stevenle-duple/memory/duple-pet-companion.md` to record: the toolkit is now a private GitHub repo (`claude-pets`), the `/pets` command surface, the Claude-Design (no-OpenAI) hatch pipeline, 5 bundled starters, and Duple-as-personal/gitignored with `duple-pet.zip` for device transfer. Keep it one fact; refresh `MEMORY.md`'s pointer line if the hook changed.

---

## Acceptance Criteria (final check)

- `assets/pets/` has 5 animated starters, each `spritesheet.webp` = 1536×1872 + valid `pet.json`, visually clean.
- Fresh clone + `install.sh` installs the 5 starters, wires hooks, needs **no API key**.
- `/pets`, `/pets choose`, `/pets list`, `/pets hatch` work; `/pet` still toggles.
- `SKILL.md` and `README.md` contain no `OPENAI_API_KEY` requirement; hatch references Claude Design.
- `personal-pets/` is gitignored; the pushed repo does **not** contain Duple (`git ls-files` shows none).
- `duple-pet.zip` exists for the work-laptop transfer.
- Repo pushed to a private GitHub remote.
