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

### Implemented

- L01–L03: removed the old baked shadow PNG and its generator. `shadows.gd` projects actual current sprite alpha onto one ground plane, northwest → southeast. A body, animal, current tool, house, fence, post, bench, crate, pot, stall, well or lantern is a caster. Ground layer stays below every actor, so a shadow cannot paint over a face. Source UV frame, flip, scale, translation and visibility are mirrored. Foliage and its silhouette use identical wind deformation with a pinned trunk.
- L04: 682 crown-local leaf particles, diamond-shaped with a visible vein, tumbling, drifting, falling, fading in/out; tiny matching ground shadows. The settings toggle still disables them.
- L05: visible crown motion, pot foliage, 40 live seedlings and 24 live facade flowers instead of painted soil; animated wildflowers respond to breeze too. Characters and wildlife breathe subtly while idle. Houses/rocks stay rigid. Flat atlas ground decoration is still terrain, not a raised 3D caster.
- L06: actual rendered 48-frame GIF at 10 fps, with fixed camera and real player input/animal physics. Reopened frames 00/18/34, village, forest, farm, front03, fence southwest collision overlay. Fresh full-map automated capture covers all objects/roads; this is not a claim that every final overlay was manually inspected.

### Verification completed locally

- **65 Python tests**, GDScript lint/format PASS.
- **4759 assertions Godot PASS**, including shadow count/frame/visibility/translation and leaf motion, plus the original physics/input suite (1330 trunk approaches, 12 facades, 1183 connected physically free road cells).
- **24 general + 152 close-up frames**, all 430 manifest objects and 1284 painted road tiles fully covered.
- Motion GIF: 48 frames, 10 fps. Isolated wind-driven shadow A/B: **1658 changed pixels** above RGB delta 3 at 960×540. Source actors/particles/sunlight hidden and actor physics stopped, so camera/player motion cannot explain the difference.
- All three report digests match source SHA256 `8732798009aa87ad5679452bb1d6138b7edc43c8df0602823e923cb1c04b02b4`.
- Fresh extracted ZIP: 112 source files byte-identical, clean editor import and all 4759 assertions PASS, no ERROR/leaks. Local ZIP SHA256 `c70d03a446e6785a13f235165b1513d30e1a039d5285be5d2651f84a7f35cf6b`. ZIP timestamps make repackaged archive hashes differ; use the accompanying SHA file.
- During evidence development the first motion-driver exit leaked local coroutine references, then exited abnormally. Fixed by scheduling exit after returning from the coroutine and freeing the scene while rendering is alive. Final driver exits 0, no errors/leaks. Review also caught camera follow overriding the intended fixed shot; final recording explicitly steps visuals with fixed camera while keeping actual physics/input.

### Limits

2D ground projection, not full volumetric lighting: no shadow reception on another facade, no ray tracing, no day/night system. No physical-device FPS claim. The map and game are still the same exploration prototype, not a complete RPG. “Masterpiece” is a subjective judgement; the actual motion evidence is supplied instead of asserting that standard is met.

### Delivery

Current source ZIP: `artifacts/lantern/Lantern-Valley-Godot-Project.zip`. Gallery: `index.html` via HTTP, now includes the GIF. Historical 0.1.2 remains a separate immutable release; the lighting revision is 0.1.3.
