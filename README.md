# Claude Pets 🐾

A floating desktop pet companion for Claude Code — inspired by Codex's `/pets`.
Your pet lives on screen, plays idle animations, and shows a status card per active
Claude Code session: the terminal's name, a 1-2 line summary of what Claude is doing,
and a glyph for **working** (blue spinner), **needs input** (orange clock), or
**done** (green check). Click a card to jump to that terminal; the card clears once
you've seen it.

One slash command, four moves:

| Command | What it does |
|---|---|
| `/pets` | Toggle the floating pet overlay on/off |
| `/pets choose` | List your installed pets and switch the active one |
| `/pets list` | Print installed pets and which is active |
| `/pets hatch` | Create a custom pet from your repo's vibe or your interests |

`/pet` (toggle) and `/hatch-pet` (create) still work as aliases.

## Install

```bash
./install.sh
```

Then **restart Claude Code** (or open `/hooks` once) so the status hooks load.
Start the pet with `/pets` (or `~/.claude/pets-companion/wake-pet`).

### Requirements

- **macOS + Xcode command line tools** for the floating overlay (`xcode-select --install`).
  The `/hatch-pet` creation engine is cross-platform; only the on-screen overlay is macOS-only.
- **Python 3** (the installer builds a private venv with Pillow).
- **`ffmpeg`** for preview videos during hatching (optional).
- **Claude Design** (desktop app or claude.ai) to generate a new pet's sprite when you
  `/pets hatch`. Claude itself can't generate images, so it hands you a prompt to run in
  Claude Design; the animation is built locally with no API keys. The five bundled
  starter pets work out of the box with nothing extra.

## Using it

- **Toggle:** `/pets`
- **Switch pets:** `/pets choose` — lists your installed pets; pick one and it becomes
  active and reloads.
- **Create:** `/pets hatch` — inside a repo it proposes pet concepts based on what the
  project does; otherwise it asks about your interests. It confirms direction, hands you
  a Claude Design prompt to generate one sprite, then animates it into a full atlas and
  makes it the active pet.
- **Move / resize:** drag the pet; hover it for the diagonal resize handle (size persists).
- **Quit:** right-click the pet → Tuck Away, press `q`, or `/pets` again.

## What it installs (per user, under `~/.claude/`)

| Path | What |
|---|---|
| `skills/hatch-pet/` | the pet-creation engine (+ private venv) |
| `pets-companion/` | the overlay binary, `pet_status.py`, wake/tuck/toggle scripts |
| `commands/pets.md` + `pet.md` | the `/pets` command (+ `/pet` toggle alias) |
| `pets/` | installed pets, the `active` pointer, and live `status/` cards |
| `settings.json` | status-publishing hooks (UserPromptSubmit/PreToolUse/PostToolUse/Stop/Notification/SessionEnd) |

Uninstall with `./uninstall.sh` (your hatched pets are left in place).

## Notes

- Five starter pets ship ready to use and fully animated: **Biscuit** (brown dog),
  **Bloop** (water slime), **Ember** (fire), **Mochi** (black cat), **Sprout** (grass
  seedling). See `FINAL/Claude Pets - Collection.html` for the lineup. The built-in Codex
  pets are **not** redistributed here (they're OpenAI's artwork) — hatch your own.
- Click-to-focus and auto-dismiss use AppleScript to talk to iTerm2; macOS will ask for
  Automation permission the first time. If denied, the pet still runs (those extras no-op).
- Notarization: the overlay is built locally on your machine by `install.sh`, so there's
  no Gatekeeper quarantine.

## Troubleshooting

**Overlay build fails with `redefinition of module 'SwiftBridging'`** (install prints
`! overlay build failed`, and the `/hatch-pet` engine still works but no pet appears on
screen). This is a stale Command Line Tools file, not a bug in Claude Pets: an older CLT
left a `module.modulemap` behind that now collides with the current `bridging.modulemap`,
which breaks **every** Swift compile on the machine. Move the stale duplicate aside:

```bash
sudo mv /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap \
        /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap.bak
```

Then re-run `./install.sh` (or just rebuild: `swiftc -O ~/.claude/pets-companion/duple_pet.swift -o ~/.claude/pets-companion/duple_pet`)
and start the pet with `/pets`. Reinstalling the Command Line Tools
(`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`) also fixes it.
