# Prompt: recolor default cat sprites to match a specific real cat

Recolor the default cat sprite set so it depicts one specific real cat. The goal is instant recognition by the owner, so follow the marking map and palette below exactly. Do not invent extra markings and do not raise contrast beyond what is described.

## Identity in one paragraph

A fluffy semi-longhaired cat of Siberian type, warm mushroom-gray with low-contrast darker tabby striping, a broad white bib running from the chin down the chest to the belly, and all four paws white. The face has a signature look: pale cream "spectacles" around large gooseberry-green eyes, framed by thin darker gray eyeliner-like rims, a small terracotta-pink nose, white muzzle and chin, long white whiskers, ear tips with small lynx tufts, and long white fur inside the ears. The tail is an enormous gray plume with a paler frosted underside, almost as long as the body. Overall silhouette is soft and round, with a big ruff around the neck and fluffy trousers on the hind legs.

## Color palette (approximate, sample from a warm-light photo if possible)

- body_gray_mid: #918A81 — warm taupe-gray, the main body color. Warm, leaning mushroom/beige. Never a cold blue-gray
- stripe_gray_dark: #6B645D — darker gray-brown for the subtle tabby striping, the top of the tail, the thin lines on the face
- frost_gray_light: #C9C3BA — pale silvery frost on fur tips, cheeks near the ruff, tail underside, trousers highlights
- white: #F4F1EA — bib, muzzle, chin, all four paws, belly. Slightly warm white, not pure #FFFFFF
- cream_buff: #D9BFA0 — the spectacles around the eyes, strongest as eyebrow patches above the eyes
- eye_green: #A9B573 with a darker olive rim #6F7A3E and a black pupil — pale gooseberry green, slightly yellower toward the pupil
- nose_pink: #C9877B — small terracotta-pink nose; toe beans a lighter pink #D8A49E
- inner_ear_pink: #D3A296 — visible pink skin at the inner ear edge

Hex values are estimated from photos taken under different lighting, so treat them as a starting point and keep the relationships between them (warm gray body, low-contrast stripes, warm white) rather than the exact numbers.

## Marking map, region by region

**Head.** Warm gray on top and the back of the head. A faint tabby "M" on the forehead, drawn in stripe_gray_dark at low contrast. Thin darker streaks run from the outer corners of the eyes toward the ears and cheeks. The lower half of the face turns white: muzzle, chin, and throat are white, and the muzzle is puffy.

**Eyes.** Large, round-almond, pale gooseberry green. Each eye has three layers: a thin dark gray outer rim (eyeliner effect), then a cream_buff ring (the spectacles), then the gray of the head. The cream is widest above the eyes, forming two soft eyebrow patches. This eye area is the single most recognizable feature of the face.

**Ears.** Medium size, set fairly wide. Pink skin shows along the inner edge, long white furnishing hair fills the inside, and each tip carries a small lynx tuft that extends past the ear outline.

**Whiskers.** Long, dense, white, spreading wide from the muzzle, plus white whisker hairs above the eyes. If the sprite style allows whiskers, they must be white.

**Neck and chest.** A prominent ruff: white at the front, shading to frost_gray_light and then body_gray_mid at the sides. The white bib is broad and continuous, running from the chin over the throat and chest down between the front legs to the belly.

**Body.** body_gray_mid over the back, shoulders, sides, and hips. Subtle mackerel-type striping in stripe_gray_dark on the flanks and along the spine; from a distance the body reads as soft solid gray with a light silvery shimmer on the fur tips. The belly is white and fluffy, the belly fur slightly wavy.

**Legs and paws.** All four paws white. Front legs: white mittens reaching roughly to the wrist. Hind legs: white socks reaching the hock. Above the white, the legs are body gray. Hind legs carry fluffy gray trousers. Toe beans are pink.

**Tail.** The dominant feature of the silhouette. A huge plume, nearly body length, gray on top in body_gray_mid to stripe_gray_dark, with a clearly paler frosted underside in frost_gray_light. It should look at least twice as thick as a shorthair cat tail.

**Optional micro-detail.** A tiny cream fleck on the chin/jaw area. Include only if resolution allows; skip at small sizes.

## Silhouette rules

- the outline must read as fluffy: slightly ragged edges on the ruff, trousers, belly, and tail, never a smooth shorthair contour
- the ruff visually widens the neck; the head sits in a collar of fur
- when sitting, the tail wraps around the front paws as a thick fluffy arc
- when curled up, the cat becomes an almost perfect gray ball with the plume tail covering the paws and nose

## Priority order for low resolutions

If the sprite is too small to hold everything, keep features in this order and drop from the bottom:

1. warm gray body plus white bib plus four white paws
2. huge fluffy tail with paler underside
3. green eyes
4. pink nose, white muzzle
5. cream eyebrow patches above the eyes
6. lynx tufts on ear tips
7. subtle flank striping
8. dark eyeliner rims around the eyes

## What to avoid

- cold blue-gray or pure neutral gray for the body; the gray is warm
- high-contrast, clearly drawn tiger stripes; the striping is faint
- any orange or red patches; the only warm accent is the pale cream around the eyes
- a fully white or fully gray face; the split is gray top, white bottom
- a thin smooth tail or a slim shorthair silhouette
- pure white #FFFFFF; the whites are slightly warm

## Recommended sprite height

128 px for the standing/sitting pose. At this height the cream spectacles (2–3 px ring), lynx tufts (1–2 px), eyeliner rims (1 px), and low-contrast flank striping all survive as distinct pixels. 96 px still works with minor loss in the eye area. 64 px is the practical floor: keep only priorities 1–5 from the list above. Below 64 px the cat degrades to "generic gray cat with white chest" and stops being recognizable as this particular animal.