#!/usr/bin/env python3
"""Ramona sprite recolor helper.

Two passes (see cat_pack/ramona/RECOLOR.md):
  pass 1  deterministic source-ramp -> Ramona-ramp remap (identical every frame)
  pass 2  marking overlay from a per-frame spec (bib/muzzle/nose/leg/paws), eyes auto

Commands:
  map    print an ASCII anatomy map of a frame + detected eyes + face axis
  apply  recolor a frame from a spec json, write PNG, assert on-palette

Coordinates are always in the 64x64 cell's own pixel space.
"""
import argparse, json, os
from collections import Counter
from PIL import Image

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(SKILL_DIR, "..", "..", ".."))
DEFAULT_SHEET = os.path.join(REPO, "cat_pack", "cat 1 (64Â64).png")

# --- Ramona palette (all Zenit-241) ---
OUTLINE, SHADOW, BODY, FROST = "#312b30", "#504347", "#9a877e", "#c2b1a9"
WHITE, GREEN, NOSE = "#e2d3cf", "#a6cf78", "#ca737b"
RAMONA = {OUTLINE, SHADOW, BODY, FROST, WHITE, GREEN, NOSE}

def t(h):
    h = h.lstrip("#"); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), 255)

# pass-1 remap: source ramp -> Ramona ramp
REMAP = {
    (18,14,20,255):   t(OUTLINE),
    (49,43,48,255):   t(SHADOW),
    (80,67,71,255):   t(BODY),
    (114,99,97,255):  t(FROST),
    (154,135,126,255):t(FROST),   # highlight merged into frost
    (211,223,225,255):t(BODY),    # cold eye shine killed; eyes repainted in pass 2
}
SHINE = (211,223,225,255)                       # source eye pixel = eye anchor
INTERIOR_SRC = {(80,67,71,255),(114,99,97,255),(154,135,126,255),(211,223,225,255)}

def load_frame(sheet, row, col):
    src = Image.open(sheet).convert("RGBA")
    return src.crop((col*64, row*64, col*64+64, row*64+64)).copy()

def detect_eyes(cell):
    px = cell.load()
    return [(x,y) for y in range(64) for x in range(64) if px[x,y] == SHINE]

def ascii_map(cell):
    px = cell.load()
    s = {(18,14,20,255):"#",(49,43,48,255):"X",(80,67,71,255):"o",
         (114,99,97,255):"-",(154,135,126,255):".",(211,223,225,255):"E"}
    x0,y0,x1,y1 = cell.getbbox() or (0,0,64,64)
    out = ["    " + "".join(str(x%10) for x in range(x0,x1))]
    for y in range(y0,y1):
        out.append(f"{y:>3} " + "".join(" " if px[x,y][3]==0 else s.get(px[x,y],"?")
                                        for x in range(x0,x1)))
    return "\n".join(out)

def recolor(cell, spec):
    px = cell.load()
    eyes = (detect_eyes(cell) if spec.get("eyes","auto")=="auto"
            else [tuple(e) for e in spec["eyes"]])
    if "axis" in spec:            axis = spec["axis"]
    elif len(eyes) == 2:          axis = (eyes[0][0] + eyes[1][0]) / 2.0
    else:                         axis = 31.5
    # pass 1
    interior = set()
    for y in range(64):
        for x in range(64):
            p = px[x,y]
            if p in INTERIOR_SRC: interior.add((x,y))
            if p in REMAP:        px[x,y] = REMAP[p]
    W, G, N = t(WHITE), t(GREEN), t(NOSE)
    def pw(x,y):                                 # paint white, interior only
        if (x,y) in interior: px[x,y] = W
    def mir(x): return int(round(2*axis - x))
    # pass 2 — markings (half-masks are mirrored about the axis)
    for ys,xs in spec.get("muzzle",{}).items():
        for x in xs: pw(x,int(ys)); pw(mir(x),int(ys))
    for ys,xs in spec.get("bib_half",{}).items():
        for x in xs: pw(x,int(ys)); pw(mir(x),int(ys))
    for y in spec.get("paw_rows",[]):
        for x in range(64):
            if (x,y) in interior: px[x,y] = W
    wl = spec.get("white_leg")
    if wl:
        r0,r1 = wl["rows"]
        for y in range(r0, r1+1):
            for x in wl["cols"]: pw(x,y)
    for x,y in spec.get("white_px",[]): pw(x,y)
    for (ex,ey) in eyes:                          # 2px green iris in socket, no accent
        px[(ex,ey)] = G; px[(ex,ey+1)] = G
    for x,y in spec.get("nose",[]): px[(x,y)] = N
    return {"eyes": eyes, "axis": axis}

def palette_report(cell):
    c = Counter("#%02x%02x%02x" % p[:3] for p in cell.getdata() if p[3] > 0)
    off = {k:v for k,v in c.items() if k not in RAMONA}
    return dict(c), off

def main():
    ap = argparse.ArgumentParser(description="Ramona sprite recolor helper")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("map","apply"):
        p = sub.add_parser(name)
        p.add_argument("--row", type=int, required=True)
        p.add_argument("--col", type=int, required=True)
        p.add_argument("--sheet", default=DEFAULT_SHEET)
        if name == "apply":
            p.add_argument("--spec", required=True)
            p.add_argument("--out", required=True)
            p.add_argument("--scale", type=int, default=0, help="also write out.x<scale>.png")
    a = ap.parse_args()
    cell = load_frame(a.sheet, a.row, a.col)
    if a.cmd == "map":
        print(ascii_map(cell))
        eyes = detect_eyes(cell)
        axis = (eyes[0][0]+eyes[1][0])/2.0 if len(eyes)==2 else None
        print(f"\neyes (source #d3dfe1): {eyes}")
        print(f"face axis (eye midpoint): {axis}")
        return
    spec = json.load(open(a.spec))
    info = recolor(cell, spec)
    cell.save(a.out)
    if a.scale:
        cell.resize((64*a.scale, 64*a.scale), Image.NEAREST).save(
            a.out.replace(".png", f".x{a.scale}.png"))
    colors, off = palette_report(cell)
    print(f"saved {a.out}  eyes={info['eyes']} axis={info['axis']}")
    print(f"colors: {colors}")
    print("OFF-PALETTE: " + (str(off) if off else "none (all Zenit)"))

if __name__ == "__main__":
    main()
