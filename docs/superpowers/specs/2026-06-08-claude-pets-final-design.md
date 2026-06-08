# Claude Pets — Final Shippable v1 (Design)

Date: 2026-06-08
Status: Approved

## Goal

Finalize the Claude Pets toolkit so that:
- A single `/pets` command surface drives toggling, switching, and creating pets.
- The shareable `claude-pets/` folder installs an identical, fully-functional `/pets`
  on any machine (work laptop, colleague) with no API keys.
- 5 Claude-Design starter pets ship fully animated, ready to use out of the box.
- The owner's personal "Duple" pet travels to their own devices but is **not**
  shared with colleagues.
- The hatch pipeline uses **Claude Design** for sprite art (no OpenAI/ChatGPT tokens).

## Non-Goals

- Redrawing or restyling existing pet art.
- Cross-platform overlay support beyond the existing macOS overlay (unchanged).
- Redistributing the locally-hatched experiment pets in `~/.claude/pets/`.

## Key Facts (verified)

- Duple spritesheet is `1536x1872` = 8 cols x 9 rows (192x208 cells) — a full atlas.
- `compose_simple_pet.py` produces this exact full 8x9 atlas (all 9 animation rows:
  idle, running-right, running-left, waving, jumping, failed, waiting, running,
  review) from ONE base sprite using deterministic Pillow transforms — **zero API calls**.
- Therefore animation creation needs **no ChatGPT/OpenAI tokens**. OpenAI was only ever
  used to generate the *base sprite*, which Claude Design now produces instead.
- `claude-pets/` currently has **no `assets/pets/`** folder, so `install.sh` bundles
  zero pets today. The 5 starters exist only as raw PNGs in `FINAL/sprites/`.

## Design

### 1. Command surface — unify under `/pets`

Replace the `/pet` toggle command with a `/pets` dispatcher; keep `/pet` as a thin
alias for muscle memory.

| Command | Action |
|---|---|
| `/pets` | Toggle the floating overlay (existing `toggle-pet`) |
| `/pets choose` | List pets in `~/.claude/pets/`, user picks → repoint `active` + `restart-pet` |
| `/pets hatch` | Run the hatch-pet creation flow (skill remains the engine) |
| `/pets list` | Print installed pets + which is active |

- New helper script `choose-pet` (or `list-pets`) enumerates `~/.claude/pets/`
  directories, excluding `status` and the `active` symlink.
- The `/pets` command markdown instructs Claude to dispatch on `$ARGUMENTS`:
  bare → toggle; `choose` → list, ask, set active + restart; `hatch` → invoke skill;
  `list` → print.
- `/pet` command file stays, pointing at the same toggle behavior.

### 2. The 5 starters → real animated packages (no tokens)

For each of `biscuit, bloop, ember, mochi, sprout`:
- Input: `FINAL/sprites/<id>-256.png`.
- If the PNG has a transparent/non-flat background, flatten onto a per-pet chroma color
  far from the pet's palette before composing.
- Run `compose_simple_pet.py` → `pet.json` + `spritesheet.webp` (full 8x9 atlas).
- Write to **new** `claude-pets/assets/pets/<id>/` (the folder `install.sh` already
  expects but is currently missing — this also fixes the "installs zero pets" gap).
- Refresh `FINAL/Claude Pets - Collection.html` to preview the animated set.

Build-time check: confirm each composed atlas keys cleanly (no background halo, sprite
fully opaque). Re-chroma and recompose any pet that looks faded/eaten.

### 3. Duple — personal, kept out of the shared repo

- Copy the built Duple (`/Users/stevenle/duple/assets/pets/duple/`) into
  `claude-pets/personal-pets/duple/`.
- `install.sh` installs from **both** `assets/pets/*` (public, committed) **and**
  `personal-pets/*` (if present).
- `.gitignore` excludes `personal-pets/`, so a colleague's clone gets only the 5
  starters — never Duple.
- Work-laptop transfer: because Duple is gitignored, cloning won't bring it. Produce a
  small `duple-pet.zip` (the `personal-pets/duple/` package) carried over once
  (AirDrop/cloud). Dropping it into `personal-pets/` and re-running `install.sh`
  (or using `/pets choose` after manual copy) makes Duple available and selectable.

### 4. Hatch pipeline rewrite → Claude Design, zero OpenAI

New `/pets hatch` flow:
1. Claude proposes pet concepts (repo vibe or user interests) and confirms direction
   — unchanged from today.
2. Claude hands the user a **ready-to-paste Claude Design prompt**: house pixel-art
   style + technical constraints (single centered full-body sprite on a **solid
   background of a named chroma color** far from the pet's palette). The user edits it
   freely in Claude Design, generates, saves the PNG, and returns the file path.
3. Claude runs `compose_simple_pet.py` on that one PNG → full animated atlas → installs
   to `~/.claude/pets/<id>`, sets `active`, restarts the overlay. **No API key.**

Remove the `OPENAI_API_KEY` requirement from `SKILL.md`, `README.md`, and `install.sh`
output. The prompt must request a **solid background** so the keyer works; the compose
step must also tolerate a transparent PNG (flatten first if needed). Legacy OpenAI
scripts remain in the repo, unreferenced.

### 5. Packaging & shipping

- Add `.gitignore` (`personal-pets/`, `.DS_Store`, `.venv`, `**/.venv`, `/tmp` artifacts,
  decoded run dirs).
- Update `README.md`: new `/pets` command table, Claude Design pipeline, no OpenAI
  requirement, 5 bundled starters, Duple-is-personal note.
- `git init` → commit → `gh repo create` **private** → push.
- Verify `install.sh` is idempotent and that a clean clone installs the 5 starters,
  wires hooks, and builds the overlay on macOS.

## Acceptance Criteria

- `claude-pets/assets/pets/` contains 5 animated starter packages, each with a valid
  full 8x9 `spritesheet.webp` + `pet.json`, visually clean.
- A fresh clone + `install.sh` installs the 5 starters and wires hooks with **no API key**.
- `/pets`, `/pets choose`, `/pets list`, `/pets hatch` all work; `/pet` still toggles.
- `SKILL.md`/`README.md` contain no `OPENAI_API_KEY` requirement; hatch flow references
  Claude Design.
- `personal-pets/` is gitignored; the pushed repo does not contain Duple.
- A `duple-pet.zip` artifact exists for transferring Duple to the work laptop.
- Repo pushed to a private GitHub remote.

## Risks / Open Questions

- Starter PNG backgrounds: transparency vs flat. Mitigation: flatten-on-chroma step +
  per-pet chroma selection; verify each composed atlas.
- `compose_simple_pet.py` assumptions about input size/centering; verify against the
  256px starters and adjust the flatten/pad step if needed.
