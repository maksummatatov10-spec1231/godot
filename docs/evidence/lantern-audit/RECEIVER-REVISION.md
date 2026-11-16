# Shadow reception revision — inspection BEFORE changes

Baseline: 0.1.3, a241221. Inspected scripts/shadows.gd, cast_shadow.gdshader, foliage.gdshader, game.gd and the existing motion capture driver before modifying the game.

- R01: live silhouettes are drawn only on a ground layer; facades, crowns, characters and animals cannot receive another object's shadow.
- R02: no shared light-depth comparison between casters and elevated receivers. Overlapping ground silhouettes alone do not solve sun visibility on objects.
- R03: the delivered stills were mixed with map-audit views that intentionally hide the hero. User needs explicit clean beauty PNGs with a visible player, shadows, surroundings and particles, not just GIF/diagnostic frames.

Plan: retain the actual-sprite ground silhouettes, add shared light-space height/depth maps built from the same current sprite alpha, deformation and frames, and shade raised receivers by comparing their light-space depth. Separate static/windy and moving caster buffers to avoid draw-order overwrites between tall buildings and shorter animals. Supply actual rendered gameplay stills including a clear facade/character shadow-reception example. No generated concept images and no claim of literally unlimited rendering.

Verification pending.
