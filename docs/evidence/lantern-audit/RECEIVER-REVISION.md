# Shadow reception revision — inspection BEFORE changes

Baseline: 0.1.3, a241221. Inspected scripts/shadows.gd, cast_shadow.gdshader, foliage.gdshader, game.gd and the existing motion capture driver before modifying the game.

- R01: live silhouettes are drawn only on a ground layer; facades, crowns, characters and animals cannot receive another object's shadow.
- R02: no shared light-depth comparison between casters and elevated receivers. Overlapping ground silhouettes alone do not solve sun visibility on objects.
- R03: the delivered stills were mixed with map-audit views that intentionally hide the hero. User needs explicit clean beauty PNGs with a visible player, shadows, surroundings and particles, not just GIF/diagnostic frames.

Plan: retain the actual-sprite ground silhouettes, add shared light-space height/depth maps built from the same current sprite alpha, deformation and frames, and shade raised receivers by comparing their light-space depth. Separate static/windy and moving caster buffers to avoid draw-order overwrites between tall buildings and shorter animals. Supply actual rendered gameplay stills including a clear facade/character shadow-reception example. No generated concept images and no claim of literally unlimited rendering.

- R04 (composition): existing courtyard trees are too far north of the southern facades to make cross-object reception easy to see. Move the tree at (552,662) feet to (536,728), into the empty strip between the two southern houses, keeping crown/props/roads separate; validate trunk collision and an unchanged-camera facade A/B. This is a real map placement, not a screenshot-only inserted occluder.

## Implementation and local checks

- Shared light-space buffers: static/windy and moving sprites are rasterised separately, strips globally sorted by actual light height, alpha discarded rather than overwriting previous opaque pixels. Receivers compare the maximum depth from both maps, using the same projection, current source frames/offsets, flips and wind as visible sprites. Source-sheet references are held strongly so switching a tool cannot invalidate atlas texture IDs.
- Every raised registered sprite is a receiver, including facades, crowns, player/tool, animals, flowers and props. Removed the ground-only restriction; floor silhouettes remain separate for legible ground contact.
- Moved the existing courtyard tree as planned; source art, 430 objects, 938 solids, 341 trunks, 1330 tested approaches, all doors and connected roads remain valid. No screenshot-only facade occluder was inserted.
- Clean PNG driver freezes time/camera/poses for reproducible stills; the wildlife portrait stages existing game actors for readability, not painted-in figures. Four world views plus a facade/hero A/B (reception off only in the diagnostic image).
- Local headless Godot **5892 assertions PASS**; **66 Python tests PASS**, lint/format PASS. Local real-render A/B has 241 facade pixels and 1251 hero pixels changed above RGB delta 12 at 960×540, with facade ROI excluding the hero and pot.

## Honest graphics diagnostic status before CI

Local PNGs rendered correctly but the legacy sandbox ANGLE/SwiftShader fallback **exited with SIGSEGV after capture**. Reports correctly remain FAIL; exit status was not ignored. A native diagnostic located the failure in `marl::Scheduler::enqueue` inside `libvk_swiftshader.so`. Audio playback leaks in the initial custom capture were independently fixed by marking evidence mode BEFORE scene `_ready`. GPU target/material references are explicitly detached while the renderer is alive and readbacks fence GPU work; this alone did not cure the SwiftShader process-exit failure. A newer 138 ANGLE also failed, and the 153 package supplied no usable EGL exports; the original pinned private backend was restored. No changes to the private EGL shim or signal interposition are included in the game or committed tools.

The normal supported Compatibility/Mesa pipeline will independently render and validate all current sources in CI before packaging/publication. Pending that result, the local portable exit must NOT be described as fixed or as a passing full pipeline.

