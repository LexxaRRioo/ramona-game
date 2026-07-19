# Ramona recolor — process and recipe

Recolor the default black-cat sprite set (`cat_pack/cat 1 (64Â64)`) so every frame
depicts Ramona, following `cat recolor prompt.md`. This file records the finished
first frame, the decisions we locked, and the exact steps to recolor the remaining
frames consistently.

## Source layout

- Sheet: `cat_pack/cat 1 (64Â64).png` and `.aseprite`, one flat canvas 896×4608, RGB.
- Grid: 14 columns × 72 rows of 64×64 cells. Frame `(row, col)` lives at pixel
  `(col*64, row*64)`.
- The cat inside a cell is small: the sitting front pose occupies roughly a 28×32 px
  area (bbox `(20,16)`–`(48,48)`), well below the prompt's 64 px "recognizability
  floor", so only marking priorities 1–4 are held; striping, eyeliner rims, and
  separate lynx-tuft coloring are dropped.
- Shared palette: `cat_pack/Palette.gpl` (Zenit-241). All recolor output snaps to it.
- Row 43 is the front-facing sitting animation (cols 0–6). Frame `(43,0)` is the one
  finished here (owner's reference "Image #1").

## Source uses 6 colors (a dark gray ramp)

| Hex | Role in source | px in frame (43,0) |
|---|---|---|
| `#120e14` | outline / darkest | 177 |
| `#312b30` | dark shadow | 78 |
| `#504347` | mid body (dominant) | 213 |
| `#726361` | light body | 62 |
| `#9a877e` | highlight | 10 |
| `#d3dfe1` | eye shine (cold, off-warm) | 2 |

## Decisions locked with the owner

1. **Recolor inside the existing silhouette only.** No outline/shape edits, so the
   recipe stays animation-safe across every frame.
2. **Snap all colors to Zenit-241.** Where the numerically-nearest Zenit color is a
   cold lavender (white `#F4F1EA`→`#e1dee7`, frost `#C9C3BA`→`#bdb5c8`), override to
   the warm taupe ramp instead — the prompt forbids cold grays and calls the whites
   warm.
3. **Marking priorities 1–4** (warm gray body, white bib, white paws, pale-underside
   tail, green eyes, pink nose, white muzzle).
4. **Bib is mirror-symmetric** about the body centerline (axis x=31.5 in this frame).
   Do not auto-center per row — the tail pixels skew the detected center and the bib
   drifts sideways.
5. **Eyes: 2 px solid green iris, no light accent** (chosen option "B"). The green
   sits *in* the socket, not above it. No white catchlight (rejected as glare-like).
6. **One white front leg**, merged into the bib, on **Ramona's own left = viewer's
   right** side of the sprite. The other front leg stays gray with a white paw.
7. **Nose: 2 px terracotta pink**, centered.

## Palette (Ramona, all Zenit-241)

| Name | Hex | Use |
|---|---|---|
| outline | `#312b30` | outline / darkest edge |
| shadow | `#504347` | body shadow, leg divisions |
| body | `#9a877e` | main warm mushroom-gray |
| frost | `#c2b1a9` | tail underside, ruff/frost highlights |
| white | `#e2d3cf` | bib, paws, white leg, muzzle (warm white) |
| green | `#a6cf78` | eye iris |
| nose | `#ca737b` | nose |

## Two-pass method

Recoloring each frame is two passes: a **deterministic color remap** (identical for
every frame) and a **manual marking overlay** (coordinates differ per pose).

### Pass 1 — color remap (automatic, same for all frames)

Replace source ramp → Ramona ramp. This alone turns the black cat into a warm gray
cat and reserves `#e2d3cf` for painted whites.

```
#120e14 -> #312b30   (outline)
#312b30 -> #504347   (shadow)
#504347 -> #9a877e   (body)
#726361 -> #c2b1a9   (frost)
#9a877e -> #c2b1a9   (merge highlight into frost)
#d3dfe1 -> #9a877e   (kill the cold eye pixel; eyes are repainted in pass 2)
```

Record which pixels were source *interior* (`#504347/#726361/#9a877e/#d3dfe1`) before
remapping — pass 2 only paints white onto interior pixels so the dark outline is
never overwritten.

### Pass 2 — marking overlay (per-frame, needs anatomy)

Coordinates below are for frame `(43,0)`; every other frame needs its own coordinates
read from that frame's pixels. The *rules* are constant, the *positions* are not.

- **Eyes:** find the 2 source `#d3dfe1` shine pixels — those mark the eye centers.
  Paint a 2 px vertical green iris seated in the socket. In (43,0): `(28,25),(28,26)`
  and `(35,25),(35,26)`. Face center axis = midpoint of the two eyes (x=31.5 here).
- **Nose:** 2 px pink straddling the axis, on the muzzle a couple rows below the eyes.
  In (43,0): `(31,28),(32,28)`.
- **Muzzle:** whiten the interior face pixels around the nose, symmetric about the
  axis. In (43,0): x=29–34 on rows 27–28.
- **Bib:** explicit mirror-symmetric mask, widest at the ruff and tapering down
  between the front legs. Build one half (x ≤ axis) and mirror to `63-x`. In (43,0):

  ```
  y30: 30,31        y35: 29,30,31
  y31: 29,30,31     y36: 30,31
  y32: 28,29,30,31  y37: 30,31
  y33: 28,29,30,31  y38-41: 30,31
  y34: 29,30,31     y42-44: 31
  ```
  (each row mirrored to the right half; whiten interior pixels only)
- **White front leg:** whiten the interior column of the cat's-left / viewer's-right
  front leg from where it meets the bib down to its paw, so chest and leg read as one
  white mass. In (43,0): x=34,35,36 on rows 36–44.
- **Paws:** whiten both front-paw clusters (keeps all paws white). In (43,0): rows
  45–46, the two clusters at x≈27–29 and x≈33–35.
- **Tail underside → frost:** the frost color already lands here via the pass-1
  highlight→frost merge; verify the tail's paler edge reads and nudge to `#c2b1a9`
  if a frame needs it.

Result for (43,0): 7 colors, all Zenit, no cold leftovers.

## How to recolor the next frames

1. Slice the target cell from the sheet: `src.crop((col*64, row*64, col*64+64, row*64+64))`.
2. Print an ASCII map of the cell (one symbol per source color) to read the pose's
   anatomy — **do not eyeball coordinates off a scaled preview; they drift by a few
   px** (this bit us once: eyes were placed 3 px off). Derive marking coordinates from
   the actual pixel grid, and anchor the eyes on the `#d3dfe1` shine pixels.
3. Run pass 1 (identical remap) then pass 2 (pose-specific overlay following the rules
   above).
4. Keep the bib and muzzle mirror-symmetric about that frame's own eye-derived axis.
5. For animation rows (e.g. row 43 cols 1–6), markings shift slightly frame to frame;
   place them per frame so the white bib/leg/eyes stay put on the moving body.
6. Materialize through pixel-plugin (Aseprite MCP): `import_image` the finished PNG
   into a canvas, `set_palette` to the 7 Ramona colors, `save_as` `.aseprite`,
   `export_sprite` to PNG. Verify the export is pixel-identical to the intended PNG
   before accepting.

## What to avoid (from the prompt + our iterations)

- Cold blue-gray / lavender grays. Body and whites are warm.
- Auto-centering the bib. Use an explicit symmetric mask.
- Bright white catchlight in the eye — reads as glare at this size.
- Overwriting the dark outline when painting whites — mask paints to interior only.
- High-contrast tabby stripes — dropped entirely at this resolution.

## Family engine (scaling past hand-authored specs)

The whole 387-frame sheet is 4 marking-families, auto-detected per frame from the eyes and
silhouette: FRONT (2 eyes), SIDE-L / SIDE-R (1 eye, left/right of centre), REAR (0 eyes),
SLEEP (0 eyes, wide silhouette). Pass 1 and the eyes are identical for every frame, so the
only per-pose work is the white markings — and each family places them from the frame's own
geometry (eye axis, silhouette bbox, muzzle tip, bottom paw-row). SIDE-R is SIDE-L mirrored,
so 3 placers + a mirror flag cover the sheet. `recolor.py --auto` / `batch` run the engine;
hero frames still override with a `specs/*.json`.

## Done

- Rows 0–1 cols 0–3 — the 8 directional idle (r0) and stand (r1) frames: front, rear,
  side-left, side-right. Fronts curated (`sit_43_0.json`, `stand_1_0.json`, with the stand
  nose dropped one row per owner review); the six rear/side frames from `--auto`. Head kept
  at source size — a 1–2 px head-shrink was previewed and rejected (silhouette edit would
  have to propagate to every frame).

## Files

- `ramona_sit_43_0.png` / `.aseprite` — finished frame (43,0), 64×64, 7-color palette.
- `ramona_r{0,1}c{0..3}_*.png` — the 8 rows-0–1 deliverables.
- `ramona_rows01_block.png` — the 8 composited into their 256×128 sheet block.
- `ramona_rows01.aseprite` — the block, materialized with the 7-color Ramona palette
  (export verified pixel-identical to the block).
- `RECOLOR.md` — this document.
