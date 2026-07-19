#!/usr/bin/env python3
"""Ramona sprite recolor helper.

Three recolor steps (see cat_pack/ramona/RECOLOR.md):
  pass 1  deterministic source-ramp -> Ramona-ramp remap (identical every frame)
  eyes    auto-anchored on the source #d3dfe1 shine pixels (identical every frame)
  pass 2  white markings -- the ONLY per-pose variation

Pass 2 has two modes:
  --auto   family engine: classify the frame (FRONT / SIDE-L / SIDE-R / REAR /
           SLEEP) from the eyes + silhouette, then place markings from the
           frame's own geometry. Covers the whole sheet with 3 placers + a
           mirror flag. No spec needed.
  --spec   hand-authored per-frame override (specs/*.json), for hero frames that
           want curation. Takes precedence over --auto.

Commands:
  map     print an ASCII anatomy map of a frame + detected eyes + face axis
  apply   recolor one frame (--auto or --spec), write PNG, assert on-palette
  batch   recolor a whole row (--row R) or the whole sheet (--all) with --auto,
          write every frame + a labelled contact sheet for review

Coordinates are always in the 64x64 cell's own pixel space.
"""
import argparse, json, math, os
from collections import Counter
from PIL import Image, ImageDraw

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

# ---------------------------------------------------------------------------
# geometry + classification
# ---------------------------------------------------------------------------

def pass1(px):
    """Remap grays in place; return the set of source-interior pixels."""
    interior = set()
    for y in range(64):
        for x in range(64):
            p = px[x,y]
            if p in INTERIOR_SRC: interior.add((x,y))
            if p in REMAP:        px[x,y] = REMAP[p]
    return interior

def ibox(interior):
    xs = [x for x,_ in interior]; ys = [y for _,y in interior]
    return min(xs), min(ys), max(xs), max(ys)

def row_runs(interior, y):
    xs = sorted(x for (x,yy) in interior if yy == y)
    runs = []
    for x in xs:
        if runs and x == runs[-1][1] + 1: runs[-1][1] = x
        else: runs.append([x, x])
    return [(a,b) for a,b in runs]

def classify(eyes, interior):
    x0,y0,x1,y1 = ibox(interior)
    cx = (x0 + x1) / 2.0
    w, h = x1 - x0 + 1, y1 - y0 + 1
    if len(eyes) >= 2: return "FRONT"
    if len(eyes) == 1:
        return "SIDE-L" if eyes[0][0] < cx else "SIDE-R"
    return "SLEEP" if w / h > 1.5 else "REAR"

# ---------------------------------------------------------------------------
# marking placers (auto). Each writes white/nose to px, guarded to interior.
# ---------------------------------------------------------------------------

def _mk(px, interior):
    W, N = t(WHITE), t(NOSE)
    def pw(x, y):
        if (x,y) in interior: px[x,y] = W
    def pn(x, y):
        if (x,y) in interior: px[x,y] = N
    return pw, pn

def mark_front(px, eyes, interior):
    pw, pn = _mk(px, interior)
    axis = sum(e[0] for e in eyes) / len(eyes)
    a = int(round(axis)); ey = min(e[1] for e in eyes)
    x0,y0,x1,y1 = ibox(interior)
    # muzzle: small white patch just below the eyes
    for y in (ey+2, ey+3):
        for dx in (-1, 0, 1): pw(a+dx, y)
    # bib: tapering triangle down the chest centreline, mirror-symmetric on axis
    top = ey + 4
    for i, y in enumerate(range(top, y1+1)):
        hw = 2.5 - i*0.32
        if hw < 0: break
        h = int(round(hw))
        for x in range(a-h, a+h+1): pw(x, y)
    # one white front leg (viewer's right = x>axis), lower body into the paw
    legtop = top + max(1, (y1 - top)//2)
    for y in range(legtop, y1+1):
        for x in range(a+1, a+4): pw(x, y)
    # paws: whiten narrow bottom runs (both feet)
    for y in (y1-1, y1):
        for (a1,b1) in row_runs(interior, y):
            if b1 - a1 <= 4:
                for x in range(a1, b1+1): pw(x, y)
    # nose: 2 px straddling the axis
    for x in {math.floor(axis), math.ceil(axis)}: pn(x, ey+3)

def mark_side(px, eye, interior, facing):
    pw, pn = _mk(px, interior)
    left = (facing == "left")
    ex, ey = eye
    x0,y0,x1,y1 = ibox(interior)
    def isin(x,y): return (x,y) in interior
    # muzzle tip: front-most interior pixel in the eye row band
    band = [(x,y) for y in range(ey, ey+4) for x in range(64) if isin(x,y)]
    tipx = min(x for x,_ in band) if left else max(x for x,_ in band)
    tiprows = [y for x,y in band if x == tipx]
    ty = (min(tiprows) + 1) if tiprows else ey + 2
    # nose at the tip (+ one pixel toward centre)
    pn(tipx, ty)
    pn(tipx + 1 if left else tipx - 1, ty)
    # White front, anchored to the front-edge run of each row below the muzzle:
    #  - throat + chest bib -> white on BOTH facings
    #  - the near front leg is white ONLY when it is Ramona's LEFT leg, i.e. when
    #    we see her left flank (facing left). Facing right, the near leg is her
    #    right leg and stays gray (white paw only, from the sock pass).
    def band(a, b):
        if left:
            for x in range(a, min(a + 2, b) + 1): pw(x, y)
        else:
            for x in range(max(b - 2, a), b + 1): pw(x, y)
    for y in range(ty + 1, y1 + 1):
        runs = row_runs(interior, y)
        if not runs: continue
        a, b = runs[0] if left else runs[-1]      # front-most run this row
        if b - a > 4:                             # wide: chest bib
            band(a, b)
        elif y <= ty + 3:                         # narrow + high: throat, both sides
            for x in range(a, b + 1): pw(x, y)
        elif left:                                # narrow + low: front leg (her left)
            for x in range(a, b + 1): pw(x, y)
        # narrow + low + facing right: her right leg -> leave gray
    # white paw socks on every narrow bottom run (both facings)
    for y in (y1 - 1, y1):
        for (a1, b1) in row_runs(interior, y):
            if b1 - a1 <= 4:
                for x in range(a1, b1 + 1): pw(x, y)

def mark_rear(px, interior, sleeping=False):
    pw, _ = _mk(px, interior)
    x0,y0,x1,y1 = ibox(interior)
    if sleeping:
        return  # pale belly not reliably visible; leave gray body + frost tail
    # white back feet only where they form narrow foot-like runs (skip a wide sit base)
    for y in (y1-1, y1):
        runs = row_runs(interior, y)
        if len(runs) >= 2 or (runs and runs[0][1]-runs[0][0] <= 3):
            for (a1,b1) in runs:
                if b1 - a1 <= 3:
                    for x in range(a1, b1+1): pw(x, y)

# ---------------------------------------------------------------------------
# recolor drivers
# ---------------------------------------------------------------------------

def paint_eyes(px, eyes):
    G = t(GREEN)
    for (ex,ey) in eyes:
        px[ex,ey] = G; px[ex,ey+1] = G

def recolor_auto(cell):
    """Full auto recolor: pass1 + eyes + family-driven markings."""
    px = cell.load()
    eyes = detect_eyes(cell)
    interior = pass1(px)
    paint_eyes(px, eyes)
    fam = classify(eyes, interior)
    if fam == "FRONT":         mark_front(px, eyes, interior)
    elif fam == "SIDE-L":      mark_side(px, eyes[0], interior, "left")
    elif fam == "SIDE-R":      mark_side(px, eyes[0], interior, "right")
    elif fam == "SLEEP":       mark_rear(px, interior, sleeping=True)
    else:                      mark_rear(px, interior)
    axis = (sum(e[0] for e in eyes)/len(eyes)) if eyes else None
    return {"family": fam, "eyes": eyes, "axis": axis}

def recolor(cell, spec):
    """Spec-driven override (hand-authored). Mirror half-masks about the axis."""
    px = cell.load()
    eyes = (detect_eyes(cell) if spec.get("eyes","auto")=="auto"
            else [tuple(e) for e in spec["eyes"]])
    if "axis" in spec:            axis = spec["axis"]
    elif len(eyes) == 2:          axis = (eyes[0][0] + eyes[1][0]) / 2.0
    else:                         axis = 31.5
    interior = pass1(px)
    W, N = t(WHITE), t(NOSE)
    def pw(x,y):
        if (x,y) in interior: px[x,y] = W
    def mir(x): return int(round(2*axis - x))
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
    paint_eyes(px, eyes)
    for x,y in spec.get("nose",[]): px[(x,y)] = N
    return {"eyes": eyes, "axis": axis, "family": "spec"}

def palette_report(cell):
    c = Counter("#%02x%02x%02x" % p[:3] for p in cell.getdata() if p[3] > 0)
    off = {k:v for k,v in c.items() if k not in RAMONA}
    return dict(c), off

def assert_on_palette(cell, tag=""):
    _, off = palette_report(cell)
    if off:
        raise SystemExit(f"OFF-PALETTE in {tag}: {off}")

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def content_cells(sheet):
    im = Image.open(sheet).convert("RGBA")
    cols, rows = im.size[0]//64, im.size[1]//64
    out = []
    for r in range(rows):
        for c in range(cols):
            if im.crop((c*64,r*64,c*64+64,r*64+64)).getbbox():
                out.append((r,c))
    return out

def main():
    ap = argparse.ArgumentParser(description="Ramona sprite recolor helper")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("map")
    p.add_argument("--row", type=int, required=True)
    p.add_argument("--col", type=int, required=True)
    p.add_argument("--sheet", default=DEFAULT_SHEET)

    p = sub.add_parser("apply")
    p.add_argument("--row", type=int, required=True)
    p.add_argument("--col", type=int, required=True)
    p.add_argument("--sheet", default=DEFAULT_SHEET)
    p.add_argument("--spec", help="hand-authored override; omit for --auto")
    p.add_argument("--auto", action="store_true", help="use the family engine")
    p.add_argument("--out", required=True)
    p.add_argument("--scale", type=int, default=0, help="also write out.x<scale>.png")

    p = sub.add_parser("batch")
    p.add_argument("--row", type=int, help="one row; omit with --all")
    p.add_argument("--all", action="store_true", help="whole sheet")
    p.add_argument("--sheet", default=DEFAULT_SHEET)
    p.add_argument("--outdir", required=True)
    p.add_argument("--sheet-scale", type=int, default=4, help="contact-sheet cell scale")

    a = ap.parse_args()

    if a.cmd == "map":
        cell = load_frame(a.sheet, a.row, a.col)
        print(ascii_map(cell))
        eyes = detect_eyes(cell)
        interior = {(x,y) for y in range(64) for x in range(64)
                    if cell.load()[x,y] in INTERIOR_SRC}
        axis = (eyes[0][0]+eyes[1][0])/2.0 if len(eyes)==2 else None
        print(f"\neyes (source #d3dfe1): {eyes}")
        print(f"face axis (eye midpoint): {axis}")
        if interior: print(f"family (auto): {classify(eyes, interior)}")
        return

    if a.cmd == "apply":
        cell = load_frame(a.sheet, a.row, a.col)
        if a.spec:
            info = recolor(cell, json.load(open(a.spec)))
        else:
            info = recolor_auto(cell)
        cell.save(a.out)
        if a.scale:
            cell.resize((64*a.scale, 64*a.scale), Image.NEAREST).save(
                a.out.replace(".png", f".x{a.scale}.png"))
        colors, off = palette_report(cell)
        print(f"saved {a.out}  family={info['family']} eyes={info['eyes']} axis={info['axis']}")
        print(f"colors: {colors}")
        print("OFF-PALETTE: " + (str(off) if off else "none (all Zenit)"))
        return

    if a.cmd == "batch":
        os.makedirs(a.outdir, exist_ok=True)
        cells = ([(a.row,c) for (r,c) in content_cells(a.sheet) if r == a.row]
                 if not a.all else content_cells(a.sheet))
        fams = Counter(); done = []
        for (r,c) in cells:
            cell = load_frame(a.sheet, r, c)
            info = recolor_auto(cell)
            assert_on_palette(cell, f"r{r}c{c}")
            out = os.path.join(a.outdir, f"r{r}c{c}.png")
            cell.save(out)
            fams[info["family"]] += 1
            done.append((r,c,info["family"]))
        # contact sheet
        S = a.sheet_scale; cw = 64*S
        maxcol = max(c for _,c in cells) + 1
        rws = sorted({r for r,_ in cells})
        sheet = Image.new("RGBA", (maxcol*cw + (maxcol+1)*4,
                                   len(rws)*(cw+14) + 4), (48,48,52,255))
        d = ImageDraw.Draw(sheet)
        for r,c,fam in done:
            gy = rws.index(r); x = 4 + c*(cw+4); y = 4 + gy*(cw+14)
            im = Image.open(os.path.join(a.outdir, f"r{r}c{c}.png")).convert("RGBA")
            sheet.alpha_composite(im.resize((cw,cw), Image.NEAREST), (x, y+12))
            d.text((x, y), f"r{r}c{c} {fam[:4]}", fill=(255,220,120,255))
        csheet = os.path.join(a.outdir, "_contact.png")
        sheet.save(csheet)
        print(f"batch: {len(done)} frames -> {a.outdir}")
        print(f"families: {dict(fams)}")
        print(f"contact sheet: {csheet}")
        return

if __name__ == "__main__":
    main()
