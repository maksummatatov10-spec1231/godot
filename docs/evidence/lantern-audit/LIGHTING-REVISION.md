# Lighting and motion revision — 2026-11-15

## Inspection FIRST (baseline 0.1.2, a8c339a)

Opened the actual 02-village, 05-forest and 10-wildlife-surprise renders and read game.gd, actor.gd, atmosphere.gd and the map shadow generator BEFORE making game changes.

- L01: most building shadows virtually invisible. Baked row projection overwrites earlier alpha rows instead of unioning them. The short and faint result does not communicate a sunny scene.
- L02: player, traveller, wildlife and held equipment have no projected silhouette shadows, only small contact ellipses. Static map shadows cannot follow them.
- L03: tree shadows do not follow crown movement; sunlight overlay is not a substitute for cast shadows.
- L04: leaves are 80 thin lines scattered over the whole world, often not visible; they do not visibly fall from crowns or tumble.
- L05: wind deformation is subpixel and imperceptible at normal gameplay scale; idle actors appear completely frozen.
- L06: no motion evidence was delivered. Still screenshots cannot prove moving leaves, crown motion, or animation-following shadows.

Scope: replace the baked runtime shadow layer with ground-projected alpha silhouettes for every placed sprite, lantern, flower, character, animal and held tool (water ripples are surface effects, not solid casters). Same northwest light direction throughout. This is a 2D projection, NOT ray-traced lighting or inter-object light occlusion. Houses/rocks remain rigid; animate foliage, flowers, water, characters and airborne particles naturally. Preserve collision geometry and sorting.

## Verification

Pending implementation and fresh real rendered evidence. Historical 0.1.2 reports do not validate the revised sources.
