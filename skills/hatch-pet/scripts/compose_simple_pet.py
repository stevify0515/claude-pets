#!/usr/bin/env python3
"""Reliable pet builder: turn ONE clean base sprite into a full animated atlas.

Keys out the chroma background from a generated base image, then composes a
1536x1872 / 8x9 / 192x208 atlas by animating that single sprite with classic
sprite transforms (idle breathe, jump arc, lean, wave-tilt, deflate). This is a
robust fallback to multi-pose generation — it never produces empty/garbled frames
and needs no extra image-API calls. Output: spritesheet.webp + pet.json.

Usage:
  compose_simple_pet.py --base base.png --chroma '#00FF00' \
    --id ember --name Ember --description "A tiny fire companion." --out-dir DIR
"""
from __future__ import annotations
import argparse, json
from pathlib import Path
from PIL import Image

CW, CH = 192, 208
ATLAS_W, ATLAS_H = 1536, 1872
ROWS = {  # state: (row_index, frame_count)
    "idle": (0, 6), "running-right": (1, 8), "running-left": (2, 8), "waving": (3, 4),
    "jumping": (4, 5), "failed": (5, 8), "waiting": (6, 6), "running": (7, 6), "review": (8, 6),
}


def sample_bg(img: Image.Image) -> tuple[int, int, int]:
    """Median color of the outer border ring — the real background gpt-image produced."""
    rgb = img.convert("RGB"); w, h = rgb.size; px = rgb.load()
    pts = []
    for x in range(0, w, 4):
        pts.append(px[x, 0]); pts.append(px[x, h - 1])
    for y in range(0, h, 4):
        pts.append(px[0, y]); pts.append(px[w - 1, y])
    rs = sorted(p[0] for p in pts); gs = sorted(p[1] for p in pts); bs = sorted(p[2] for p in pts)
    m = len(pts) // 2
    return (rs[m], gs[m], bs[m])


def key_out(img: Image.Image, hint_hex: str, hard: int = 100, soft: int = 160) -> Image.Image:
    """Key the auto-detected background color (gpt-image rarely emits a pure chroma)."""
    img = img.convert("RGBA")
    r0, g0, b0 = sample_bg(img)
    hard2, soft2 = hard * hard, soft * soft
    out = []
    for (r, g, b, a) in img.getdata():
        d2 = (r - r0) ** 2 + (g - g0) ** 2 + (b - b0) ** 2
        if d2 <= hard2:
            out.append((r, g, b, 0))
        elif d2 < soft2:
            d = d2 ** 0.5
            out.append((r, g, b, min(a, int(255 * (d - hard) / (soft - hard)))))
        else:
            out.append((r, g, b, a))
    img.putdata(out)
    return img


def base_tile(base_path: Path, chroma: str) -> Image.Image:
    """Keyed, trimmed, centered sprite fitted into a single 192x208 cell."""
    img = key_out(Image.open(base_path), chroma)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    # Fit inside a safe area with padding.
    max_w, max_h = CW - 24, CH - 28
    scale = min(max_w / img.width, max_h / img.height)
    img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.LANCZOS)
    tile = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    tile.alpha_composite(img, ((CW - img.width) // 2, (CH - img.height) // 2))
    return tile


def seq_for(state: str, n: int):
    """Per-frame (dx, dy, scale_x, scale_y, rotation_deg)."""
    if state in ("idle", "waiting"):
        s = [(0, 0, 1, 1, 0), (0, -1, 1.0, 1.01, 0), (0, -2, 1.0, 1.02, 0),
             (0, -2, 1.0, 1.02, 0), (0, -1, 1.0, 1.01, 0), (0, 0, 1, 1, 0)]
    elif state == "review":
        s = [(0, 0, 1, 1, 0), (2, 0, 1, 1, -2), (3, -1, 1, 1, -3),
             (3, -1, 1, 1, -3), (2, 0, 1, 1, -2), (0, 0, 1, 1, 0)]
    elif state == "waving":
        s = [(0, 0, 1, 1, 0), (0, -2, 1, 1, -10), (0, -2, 1, 1, 10), (0, 0, 1, 1, 0)]
    elif state == "jumping":
        s = [(0, 5, 1.07, 0.9, 0), (0, -12, 0.98, 1.07, 0), (0, -24, 1.0, 1.0, 0),
             (0, -10, 0.99, 1.04, 0), (0, 5, 1.07, 0.9, 0)]
    elif state == "failed":
        s = [(0, 0, 1, 1, 0), (0, 2, 1.02, 0.97, 0), (0, 4, 1.04, 0.93, 0), (0, 6, 1.06, 0.9, 0),
             (0, 7, 1.07, 0.88, -3), (0, 7, 1.07, 0.88, 3), (0, 7, 1.07, 0.88, 0), (0, 6, 1.06, 0.9, 0)]
    else:  # running-right / running-left / running: bob
        s = [(0, 0, 1, 1, 0), (0, -3, 1.0, 1.0, 0)] * 4
    return (s * ((n // len(s)) + 1))[:n]


def make_frame(tile: Image.Image, dx, dy, sx, sy, rot) -> Image.Image:
    t = tile
    if sx != 1 or sy != 1:
        t = t.resize((max(1, int(CW * sx)), max(1, int(CH * sy))), Image.LANCZOS)
    if rot:
        t = t.rotate(rot, expand=True, resample=Image.BICUBIC)
    cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    ox = (CW - t.width) // 2 + int(dx)
    oy = (CH - t.height) // 2 + int(dy)
    cell.alpha_composite(t, (ox, oy))
    return cell


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--chroma", required=True)
    ap.add_argument("--id", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--description", required=True)
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    tile = base_tile(Path(args.base), args.chroma)
    atlas = Image.new("RGBA", (ATLAS_W, ATLAS_H), (0, 0, 0, 0))
    for state, (row, n) in ROWS.items():
        seq = seq_for(state, n)
        for col, (dx, dy, sx, sy, rot) in enumerate(seq):
            atlas.alpha_composite(make_frame(tile, dx, dy, sx, sy, rot), (col * CW, row * CH))

    out = Path(args.out_dir).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    atlas.save(out / "spritesheet.webp", format="WEBP", lossless=True, quality=100, method=6)
    (out / "pet.json").write_text(json.dumps({
        "id": args.id, "displayName": args.name,
        "description": args.description, "spritesheetPath": "spritesheet.webp",
    }, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "pet_dir": str(out)}, indent=2))


if __name__ == "__main__":
    main()
