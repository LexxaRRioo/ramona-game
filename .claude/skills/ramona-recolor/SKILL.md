---
name: ramona-recolor
description: Recolor a default black-cat sprite frame from cat_pack into Ramona (warm gray, white bib/paws/one white leg, green eyes, pink nose), snapped to the Zenit-241 palette. Use when recoloring frames of "cat 1 (64Â64)" to Ramona, applying the two-pass recolor recipe, or continuing the sprite-recolor work.
---

# Ramona recolor

Recolor frames of `cat_pack/cat 1 (64Â64).png` (14×72 grid of 64×64 cells) into
Ramona. Full rationale and palette table: `cat_pack/ramona/RECOLOR.md`. This skill
automates the deterministic parts and drives the interactive review loop.

## Method

Two passes. `recolor.py` does both; you author the per-frame spec for pass 2.

- **Pass 1 (automatic, identical every frame):** remap the 6 source ramp colors to the
  7-color Ramona ramp. Eyes are auto-detected from the source `#d3dfe1` shine pixels —
  never place eyes by eye; the helper anchors them.
- **Pass 2 (per-frame spec):** paint the white bib, muzzle, nose, one white front leg,
  and paws. Positions differ per pose, so read the frame's anatomy first.

## Workflow per frame

1. Read the anatomy — do not eyeball a scaled preview, coordinates drift a few px:
   ```
   python3 .claude/skills/ramona-recolor/recolor.py map --row R --col C
   ```
   Note the detected eyes and face axis it prints.
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
- One white front leg (Ramona's left = viewer's right), merged into the chest; the
  other front leg stays gray with a white paw.

## Batch

Row 43 cols 0–6 is the sitting animation; markings shift slightly per frame, so give
each its own spec. Process a row frame by frame, keeping the bib/leg/eyes registered on
the moving body, and review before committing.
