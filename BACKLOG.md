Ideas checklist - add as they come up, check off once shipped (note the version). Not a roadmap; plan.md's phases are the roadmap. This is the "someday" pile.

## Reference

- `cat_pack/black cat with text.png` is a labeled reference sheet for the same 14-col grid as `ramona_sheet.png`/`cat_pack/cat 1 (64×64).png` (row indices line up, at least through the low-numbered rows checked so far - it has 66 rows vs. the other two's 72, so don't assume alignment holds at the tail without checking). Its labels are WHITE text on a transparent background - invisible composited onto white, only legible composited onto a dark background. Use this before guessing at a pose from silhouette alone.

## Animation / sprite variety

- [x] Fix wrong grooming pose: row 17 (previously wired as `groom`) is actually labeled "Scratch (sit, left)" in the reference sheet - raises the paw above her head, not a wash. Row 12 ("Lick paw sit front") is the real grooming motion, paw stays at face height. Swapped - pending release.
- [x] Add a rare (~5%) scratch variant to `.groom` using row 17/18 ("Scratch (sit, left/right)") - the pose I originally mistook for grooming. Pending release.
- [x] Slow the grooming loop down with a pause between wash cycles (`CatClip.loopPause`) instead of an unbroken loop - pending release.
- [x] Real run/leap animation for .seekAttention (rows 10/11) instead of a sped-up walk cycle - 0.1.2. Speed bumped from 2x to 4x walkSpeed - pending release.
- [x] Grooming (lying variant): row 13, "Lick paw lie front" - same wash motion as the main `groom`, but lying down. Plays instead of the sitting groom when she was just sleeping (previousAction == .sleep) - pending release.
- [ ] Seek-attention variant: sits in a far corner and meows - likely row 14 "Meow sit front" (3 frames, annoyed/wide-eyed look). Verify pose before wiring up.
- [ ] Seek-attention variant: lies down/leaps in either direction - candidate is a mirrored leaping/stretching pose (2 frames, L/R) surfaced during this session's screenshots, exact row not yet identified against the reference sheet.
- [ ] Idle pose additions (rows not yet identified - check against `black cat with text.png`):
  - Single-frame alert sit, tail up, wide-eyed ("startled/noticed something" beat).
  - Lying-down idle, 2 mirrored directions.
  - Single-frame plain lying pose.
  - A 6-frame lying-pose grid (multiple lying variants/breathing).
- [ ] Sleep pose options - a batch of frames shown looked like leaping/running poses rather than sleep poses; needs re-checking against the reference sheet before treating as sleep content (rows 44-55 loaf/sprawl variants are the likely actual candidates, see below).
- [ ] Sleep pose variety (rows 44-55 have several distinct curled/sprawled loaf poses, unused) - skipped for 0.1.2: the single lie-down transition animation only curls into one specific final pose, so swapping the held pose afterward pops. Would need either a matching transition per pose, or a plain cross-fade/cut, to do without a visible seam.
- [x] Dedicated drag/held sprite - rows 60/61 ("Hiss (front, left/right)") plays on pickup instead of freezing on whatever frame she was on - pending release.
- [x] Directional sit/stand statics - row 0 cols 2/3 ("Sit left/right") now play when she stops right after walking/climbing/seeking, instead of always the front-facing sitDown/sitIdle pair. Rows 1 (stand) and the rear/other row-0 columns are still unused.
- [ ] Side-profile run cycles (rows 29-42, 11 frames each, unused) - redundant with the row 10/11 run now wired to .seekAttention, or could be a distinct faster/slower gait.

## Bugs (known, not yet fixed)

- [x] Lie-down/curl-into-sleep transition should pick one side (left-curl or right-curl) at random each time and stick to frames from only that side - row 6's original 10-frame sequence mixed both curl directions. Split into `lieDownLeft`/`lieDownRight` (+ matching `sleepLeft`/`sleepRight`), one picked at random per settle - pending release.
- [x] Ramona sits in front of the Dock instead of on it - the Dock's AXList frame from Accessibility reports ~5pt more height than the strip's actual rendered top edge (confirmed via screenshot pixel-sampling), so she settled floating just above/in front of the visible glass. Fixed with a measured correction in `Dock.bottomFrame()` - pending release.

- [ ] Debug menu "Force Action": check whether picking a new action really applies immediately vs. waiting for the next tick - `setForcedAction` calls `evaluateAction()` synchronously and the forcedAction branch always notifies unconditionally, so this looks like it should already be instant, but wasn't confirmed live. If it does turn out delayed somewhere, fix it non-intrusively (debug-only path, shouldn't touch the real tick-gating logic).
- [ ] Dev-only toggle to hide the sprite/overlay entirely while Claude is working in the repo (rebuilding/testing draws her on screen repeatedly, which is distracting mid-session) - e.g. an env var or debug-menu switch that suppresses the overlay window without touching the real behavior engine.
- [ ] Debug menu option to auto-cycle through every CatAction on a timer (walk, idle, sleep, groom, seekAttention, climb, ...) - a quick visual QA sweep of all animations/poses without manually picking each one from Force Action.

## Behavior / feel

- [x] Fix sleeping-cat drift on repeated settle replay (catVisual child-node offset, decoupled from cat.position) - 0.1.2.
- [x] Reduce the periodic "disturbing" re-settle replay to a random 5% chance per 20s tick instead of unconditional - 0.1.2.
- [x] Fix animation freezing after picking her up mid-groom (or any action) and dropping her - this was a regression from the 5%-flourish change above: hold-end's catch-up tick got caught by the same gate meant for the passive ambient tick. Added `BehaviorEngine.resumeAfterHold()`, which always resyncs the view. Pending release.
- [ ] Rework mouse interaction: left click (and click-hold-move) should be petting/cursor-petting, not pickup. Right click should move/drag her instead. Current behavior binds pickup-drag to the left-button hold - needs to swap which button does which, and decide what a right-click-and-move gesture looks like (probably same drag mechanics as today's left-drag, just on the other button).

## Distribution / infra

- [ ] CI/CD GitHub Action to automate the release pipeline (build dmg, quarantine smoke test, sign appcast, gh release create) - outlined in conversation, not implemented. Open decision: export the Sparkle EdDSA private key to GitHub Actions Secrets, or keep the signing step manual.
- [ ] Accessibility permission re-prompt on every release build - root cause is TCC scoping grants to the ad-hoc code signature, which changes every rebuild. Only real fix is a stable paid Developer ID cert (signing release builds like the dev build's persistent "Ramona Dev" cert doesn't help - that's a separate trust mechanism from Gatekeeper's unnotarized-app prompt).
- [ ] generate_appcast keeps clobbering older entries' enclosure URLs (rewrites them to the newest tag) and drops the release-notes/ path prefix every run - has needed a manual appcast.xml fix after every run so far (0.1.1, 0.1.2). Worth scripting the fix or filing upstream.

## Content (per plan.md scope)

- [ ] Lola (second cat) - new Species JSON + sprite folder, no code change per the locked architecture decision.
- [ ] Two-cat interactions - explicitly deferred in plan.md's V1 scope.
