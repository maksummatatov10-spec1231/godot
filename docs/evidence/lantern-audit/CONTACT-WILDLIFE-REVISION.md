# Wildlife and shadow-contact revision — defects recorded before fixes

Baseline: 0.1.5, `63cc077`. User crops: image-17.png (rabbit), image-18.png (hero/contact ellipse and gap), image-19.png (tree/shadow gap).

## Confirmed defects

1. Wildlife is placeholder art: the map generator draws 16×16 animals out of a handful of rectangles/ellipses, with only four frames and an alternating one-pixel bob. Sideways rabbit incorrectly inherits the fox-like tail. No distinct idle, walk and flee gaits.
2. `actor.gd::_draw()` STILL invokes `draw_ellipse_shadow()` for EVERY character, on top of the new projected silhouette. The old ellipse is not a reception issue: it is an extra obsolete draw command and must be deleted, including the method.
3. Ground projection uses the physics/sort foot rather than the opaque sprite's actual contact pixels. Hero idle frames have last opaque row at source Y23; with sprite origin at -10 and a 32px frame, the lowest visible pixel centre is Y=-2.5 relative to the actor. Projecting about Y=0 sends that pixel ~2.1px right and 3.7px away from its source along the projection difference. Some trees end at row30 in a 32px crop, leaving transparent padding at the nominal sort foot. A compensating universal offset is therefore not correct.
4. Idle breathing scales around the sprite centre. The foot moves away from the nominal anchor while old shadow and depth passes use the unscaled physical base.
5. Independent pixel snapping of sprite/shadow transforms can round mathematically matching world anchors differently at fractional actor/camera positions.

## Required fix and checks

- Replace placeholder wildlife with detailed quadruped sprites and genuinely articulated locomotion/idle cycles, four directions, slower walk and distinct faster flee motion. Do not merely enlarge old 16px placeholders or linearly blend whole frames.
- Remove the old actor ellipse completely; do not replace it with another contact blob.
- Cache opaque contact data per texture/frame; share the SAME transformed contact plane between projected ground silhouettes, receiver shader and both light-depth passes. Keep physics/collision/sorting unchanged. Handle atlas frames, flips, scale/breathing, trees, props and tools consistently; transparent padding must not detach a caster.
- Preserve the camera-local shadow optimization. No per-frame CPU image readbacks/scanning, no return to full-world UPDATE_ALWAYS targets.
- Check real renders close up, all directions/gaits, fractional positions and several camera zooms; retain full map/physics/reception/locality/performance gates. Produce clean PNGs and actual motion evidence, not a concept illustration.

Implementation/recheck pending.
