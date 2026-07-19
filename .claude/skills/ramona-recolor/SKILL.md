---
name: ramona-recolor
description: Recolor a default black-cat sprite frame from cat_pack into Ramona (warm gray, white bib/paws/one white leg, green eyes, pink nose), snapped to the Zenit-241 palette. Use when recoloring frames of "cat 1 (64Â64)" to Ramona, applying the two-pass recolor recipe, or continuing the sprite-recolor work.
---

# Ramona recolor

Recolor frames of `cat_pack/cat 1 (64Â64).png` (14×72 grid of 64×64 cells) into
Ramona. Full rationale and palette table: `cat_pack/ramona/RECOLOR.md`. This skill
automates the deterministic parts and drives the interactive review loop.

## Method

Three steps. `recolor.py` does all of them.

- **Pass 1 (automatic, identical every frame):** remap the 6 source ramp colors to the
  7-color Ramona ramp.
- **Eyes (automatic):** auto-detected from the source `#d3dfe1` shine pixels — never
  place eyes by eye; the helper anchors them.
- **Pass 2 (markings):** the only per-pose variation. Two modes:
  - `--auto` — the **family engine**. Classifies the frame from eyes + silhouette into
    FRONT / SIDE-L / SIDE-R / REAR / SLEEP, then places bib/muzzle/nose/leg/paws from the
    frame's own geometry. Covers the whole 387-frame sheet with 3 placers + a mirror flag;
    no spec needed. Markings track an animation for free because they read each frame's
    pixels.
  - `--spec` — a hand-authored `specs/*.json` **override** for a hero frame that wants
    curation. Takes precedence over `--auto`.

Every frame in the sheet is exactly one family (eye count → 2 FRONT / 1 SIDE / 0 REAR-or-
SLEEP; eye side → L/R; wide silhouette → SLEEP). SIDE-R is SIDE-L mirrored.

## Workflow (auto first)

Default path — let the engine do it, review, override only if needed:

```
# one frame
python3 .claude/skills/ramona-recolor/recolor.py apply --auto --row R --col C --out out.png --scale 8
# a whole animation row + contact sheet
python3 .claude/skills/ramona-recolor/recolor.py batch --row R --outdir DIR
# the entire sheet + contact sheet
python3 .claude/skills/ramona-recolor/recolor.py batch --all --outdir DIR
```

`batch` asserts every frame on-palette and writes `DIR/_contact.png` for review. Inspect
the contact sheet, then curate only the frames that need it (below).

## Curating a frame with a spec (override)

1. Read the anatomy — do not eyeball a scaled preview, coordinates drift a few px:
   ```
   python3 .claude/skills/ramona-recolor/recolor.py map --row R --col C
   ```
   It prints the detected eyes, face axis, and auto family.
2. Author `specs/<name>.json` (copy `specs/sit_43_0.json`). Keys, all in the cell's
   64×64 pixel space:
   - `bib_half` `{ "y": [x,...] }` — chest pixels with x ≤ axis; mirrored automatically.
     Widest at the ruff, tapering to a single center column between the legs.
   - `muzzle` `{ "y": [x,...] }` — face pixels around the nose, x ≤ axis; mirrored.
   - `nose` `[[x,y],...]` — 2 px straddling the axis.
   - `white_leg` `{ "cols": [x,...], "rows": [y0,y1] }` — Ramona's-left / viewer's-right
     front leg, merged into the bib.
   - `paw_rows` `[y,...]` — rows whitened fully (both paws).
   - optional `white_px`, `axis`, `eyes` overrides.
3. Apply and review:
   ```
   python3 .claude/skills/ramona-recolor/recolor.py apply --row R --col C \
     --spec specs/<name>.json --out <name>.png --scale 8
   ```
   The command asserts the result is fully on-palette (`OFF-PALETTE: none`). Show the
   `.x8.png` and get approval before moving on.
4. Materialize via pixel-plugin (Aseprite MCP): `import_image` the PNG into a canvas,
   `set_palette` to the 7 Ramona colors, `save_as` `.aseprite`, `export_sprite` to PNG,
   and confirm the export is pixel-identical to `<name>.png`.

## Locked rules

- Recolor inside the existing silhouette only — never edit the outline or shape.
- Every output color must be one of the 7 Ramona colors (all Zenit-241). Prefer the
  warm taupe ramp over numerically-nearer cold lavenders.
- Bib and muzzle are mirror-symmetric about the eye-derived axis — no per-row auto-center.
- Eyes: 2 px solid green, no white catchlight.
- Only **Ramona's own left** front leg is white (full length), merged into the chest;
  her right front leg stays gray with just a white paw. By view: FRONT = white leg on
  viewer's right; faces-left profile = near front leg white (it is her left); faces-right
  profile = near front leg GRAY (it is her right), her white left leg is occluded. The
  white bib shows on every view.

## Batch

Use `batch --all` (auto engine) for the whole sheet, review the contact sheet, then curate
outliers with specs. The engine handles animation drift automatically — no per-frame spec
for routine frames.

Spot-check the SLEEP family (curled/lying, rows 44–55) before trusting `--all`: it
currently gets body + frost tail only (no white), pending a pale-belly placer.

## Done so far

- Rows 0–1 cols 0–3 (8 directional idle/stand frames): fronts curated via
  `specs/sit_43_0.json` + `specs/stand_1_0.json`, the other six from `--auto`. Deliverables
  in `cat_pack/ramona/ramona_r*.png`, materialized to `cat_pack/ramona/ramona_rows01.aseprite`.
- `specs/sit_43_0.json` also fits r0c0 (pixel-identical source frames).
