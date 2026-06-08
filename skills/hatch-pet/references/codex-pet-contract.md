# Codex Pet Contract

## Sprite Atlas

- Format: PNG or WebP.
- Dimensions: `1536x1872`.
- Grid: 8 columns x 9 rows.
- Cell: `192x208`.
- Background: transparent.
- Unused cells: fully transparent.

The webview animation uses CSS background positions from the fixed row and column counts. Do not add labels, gutters, borders, grid lines, shadows outside the cell, or extra frames.

## Local Custom Pet Package

Place files under the package directory. In this Claude Code port pass `--package-dir`
(default `$HOME/.claude/pets/<pet-name>/`); the original Codex app loads them from
`${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/`:

```text
<package-dir>/<pet-name>/
├── pet.json
└── spritesheet.webp
```

Manifest shape:

```json
{
  "id": "pet-name",
  "displayName": "Pet Name",
  "description": "One short sentence.",
  "spritesheetPath": "spritesheet.webp"
}
```

The app loads custom pets from the folder name under `${CODEX_HOME:-$HOME/.codex}/pets/`.
