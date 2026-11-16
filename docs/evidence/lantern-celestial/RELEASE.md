# Фонарщик — Тихая долина 0.3.0

## Delivered changes

- Play → four illustrated story cards with text/typewriter controls (Z/Enter next, X reveal, Escape asks before skipping). Each card has its own AI-generated scene referencing the same moss-hooded, green-coated traveler with satchel and brass lantern. Visually reviewed in-engine; small generated costume details vary. Full-frame aspect-fit preserves the character instead of cropping the feet; opaque side bars are intentional.
- New journeys start at **06:15**, day 1. Continue restores saved clock/day rather than resetting morning. Existing atomic/manual/autosave/backup behavior retained.
- Continuous analytic inclined solar/lunar trajectories drive shadow direction and length. A 29.53059-day lunar phase modulates moonlight; softened cotangent bounds grazing-angle shadow lengths without clock buckets. Palette interpolation uses quintic smootherstep. This is a stylized 2D celestial model, not location-specific astronomical ephemerides or full 3D ray tracing.
- Maximum ground opacity: sun **0.38**, moon **0.055** (also phase-dependent). Raised receivers fade with the same light strength. Moon shadows are softened. The moon moves along a visible arc; canopy shafts and lake reflection follow the shared orbit/simulation time.
- Cached, sun-independent static/pose geometry is reprojected in shaders. Conservative all-angle spatial envelopes preserve offscreen casters that can affect visible pixels. Depth maps remain camera-local; clock changes do not rebuild unchanged pose meshes. Old circular character/animal shadow underlays were not restored.

## Actual visual review and fixes

The first otherwise-passing render run exposed horizontal self-shadow stripes at nearly screen-horizontal solar angles. Both local/full reference contained this defect, so pixel equivalence alone was insufficient. Recorded before fixing in [AUDIT.md](AUDIT.md), with [rejected frame](review-01-self-shadow-acne.png).

Added continuous Jacobian-scaled raster bias to avoid interpreting a neighboring strip's depth-sampling error as a blocker. Added seven isolated real-house on/off comparisons from 13:24 through 16:00. Reopened final full 14:00, isolated-house, 16:00 and midnight images: the stripes are gone, external reception remains, and night contrast is restrained. Also reviewed the four in-engine prologue cards, the full-day/camera-angle sheets, tree-foot contact, wildlife, menu, farm and lake collision overlays. No new layout, clipping or contact defect observed in these reviewed frames.

[Open screenshot gallery](index.html) · [Accelerated celestial cycle](celestial-cycle.gif)

## Reproducible verification

Canonical final CI: [43943922040 — SUCCESS](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43943922040)

- Source commit: `2a4559b8fa3346c0087eba676c04d52cca778a4f`.
- Recorded evidence commit: `bb3c6e9`.
- All **eight** acceptance reports pass and match game SHA-256:
  `09394c7cd1cb839dae398593156e2e2244ef81768e399f01b6c28ecb66bc1b45`.
- Godot gameplay/physics: **11,961** assertions; celestial math: **70,319**; isolated save writer **54**, separate-process reader **27**; Python **78** tests. Strict warnings/lint/format pass.
- **24** camera-local/full-world comparisons: **0 pixels different above RGB 12** at 06:15, noon, 17:00 and 23:00, including forest, village, farm, raised facade and crop boundaries.
- Seven isolated self-shadow comparisons: **0 pixels different above RGB 12**. External reception still changes **327 facade pixels**, **2,224 hero pixels** in the dedicated fixed-camera A/B.
- Night shadow A/B mean RGB contribution **0.180673**, daytime **3.075281**: measured ratio **5.875%**. This is a frame-wide frozen-scene A/B measure, not a universal per-pixel contrast promise.
- Sixty continuous clock microsteps with stable selection/poses: **0 moving mesh rebuilds, 0 pose-template builds**. During the wide-hour sweep, changing lantern sprite regions and local selection can legitimately update moving batches.
- Camera-local shadow CPU update remains **3.74× / 3.94× / 5.91×** faster in village/forest/farm than the old pre-locality 0.1.4 baseline, on the same CI test. These ratios do **not** compare against 0.2.1 and are **not hardware GPU/FPS claims**.
- Foundation capture: 22 frames, zero UI overflows, restart persistence and local-lamp A/B pass. Full-map audit, wildlife/contact, actual motion and visible-collision suites pass as separate gates.

## Clean source archive

`artifacts/lantern/Lantern-Valley-Godot-Project.zip`

- **12,900,467 bytes**, SHA-256:
  `5ee795f7259681b1f8ab3ae414060190656e60452dd7f0931875df6c788df204`.
- Fresh extraction: **147 source files byte-identical** to the verified game; all eight matching validation reports included.
- Fresh Godot import and independent gameplay/math/save-writer/save-reader rechecks pass using isolated user storage. Details/logs: [clean-zip.json](clean-zip.json).
- Companion archive: `artifacts/lantern/Lantern-Valley-0.3.0-Screenshots.zip`, including the four in-engine story cards and current orbital GIF/frames.

Open the extracted `LanternValley/project.godot` in **Godot 4.7.2**, then F5. This is a **source project, not a Windows EXE**. No new 0.3.0 GitHub Release was published by this validation-only run; use the delivered local archive, not the historical 0.2.1 release ZIP.

## Scope / limitations

Canonical images are genuine Godot Compatibility renders on Mesa llvmpipe software. No physical-GPU performance or native-Windows run is claimed. This remains a 2D billboard-lighting approximation: conservative grazing-angle lengths and slope-scaled raster bias avoid instability; lantern pools do not add seven separate wall-occluded shadow maps. Generated story illustrations are not gameplay screenshots. World layout, collisions, `forest_game`, NinjaAdventure source assets and ground/map files are unchanged from the previous delivered version.
