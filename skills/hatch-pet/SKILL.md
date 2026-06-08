---
name: hatch-pet
description: Create a custom animated desktop pet companion (Codex /pets-style) — an 8x9 pixel-art sprite atlas with idle/wave/jump/run animations, packaged and made the active pet for the floating overlay. Use when the user runs /pets hatch or /hatch-pet, wants to make/hatch a pet, create a mascot for a repo, or design a companion from their interests. Infers a pet concept from the repo's vibe OR the user's interests, confirms direction, hands the user a Claude Design prompt to generate one sprite, then animates it into a full atlas with bundled deterministic scripts — no image API key required.
---

# Hatch Pet

Create a custom animated desktop pet — the same sprite format the Codex `/pets` overlay uses — and make it the active pet for the floating companion (`/pet`).

## Environment

```bash
SKILL_DIR="$HOME/.claude/skills/hatch-pet"
PY="$SKILL_DIR/.venv/bin/python"          # bundled venv with Pillow
COMP="$HOME/.claude/pets-companion"        # overlay + scripts
PETS="$HOME/.claude/pets"                  # installed pets live here
```

Run every script with `$PY`. Artwork comes from Claude Design (the user generates one sprite); preview videos need `ffmpeg` (optional).

## Step 1 — Decide the concept (always confirm direction)

Pick the intake mode from context:

**A. From the current repo (default when run inside a git repo).** Read what the project is and its vibe — `README.md`, `package.json`/`pyproject.toml`/`Cargo.toml` (name, description, deps), top-level dirs, and the product's purpose. From that, propose **2-3 distinct pet concepts** that capture the repo's personality (e.g. a database tool → a sturdy elephant-ish blob; a music app → a headphone-wearing sprite). For each: a short name, one-line personality, palette, and key visual motif.

**B. From the user's interests (when not in a repo, or the user prefers).** Ask a couple of quick questions: what they're into / the mascot's personality, any creature or object, favorite colors, and any must-have accessory. Then propose 2-3 concepts.

**Always ask the user to confirm or steer** before generating — which concept, name, palette tweaks, accessories. Do not start generating art until they pick a direction. If the user gives an explicit, complete brief up front, confirm it back in one line and proceed.

Establish a short **pet name** and a **slug id** (lowercase-kebab). Keep a visible TodoWrite checklist: 1) Get ready 2) Imagine main look 3) Pose rows 4) Hatch.

## Style

The house style is the Codex digital-pet look: small **pixel-art / 8-bit-adjacent** mascots — compact chibi proportions, chunky readable silhouette, thick dark 1-2px outline, visible stepped/pixel edges, limited palette, flat cel shading, simple expressive face, tiny limbs. No painterly/3D/glossy/anime rendering, no soft gradients, no detail that vanishes at 192x208. The bundled prompts already enforce this — keep concept prompts terse and sprite-specific.

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
Confirm it looks clean (no background halo; sprite fully opaque) — if the pet looks
faded/eaten, the background wasn't contrasting enough: ask the user to regenerate the
sprite on a more contrasting solid color and recompose.

Make the new pet active and reload the overlay:

```bash
ln -sfn "$PETS/<id>" "$PETS/active"
"$COMP/restart-pet"
```

Tell the user the pet is hatched and active, where it's saved (`$PETS/<id>`), and that `/pet` toggles it. To switch pets later, repoint `$PETS/active` at any folder under `$PETS/` and run `$COMP/restart-pet`.

## References

- `references/codex-pet-contract.md` — atlas format + `pet.json` shape.
- `references/animation-rows.md` — the 9 rows, frame counts, durations.
- `references/qa-rubric.md` — acceptance checklist.

## Rules

- Always confirm the concept/direction with the user before generating.
- The base sprite always comes from Claude Design on a solid background; never fabricate sprites locally.
- Use the deterministic scripts for geometry/atlas — never hand-build the sheet.
- Treat identity drift as a blocker even if automated QA passes.
