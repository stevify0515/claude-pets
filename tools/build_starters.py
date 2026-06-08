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
# Descriptions/identities mirror FINAL/Claude Pets - Collection.html.
PETS = {
    "biscuit": ("Biscuit", "A brown dog that ships fast and wags faster.", "#00FF00"),
    "bloop":   ("Bloop", "A bubbly water slime that goes with the flow.", "#FF00FF"),
    "ember":   ("Ember", "A wisp of flame with a warm little heart.", "#00FF00"),
    "mochi":   ("Mochi", "A black cat that naps on your keyboard and judges your code.", "#00FF00"),
    "sprout":  ("Sprout", "A grass seedling with small shoots and big ideas.", "#FF00FF"),
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
