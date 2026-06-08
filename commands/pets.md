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
