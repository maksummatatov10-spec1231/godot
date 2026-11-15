# Lantern Valley · 0.1.3 · actual-render evidence

This directory now contains the **lighting/motion revision**, not the historical 0.1.2 renders.

## Reproduce

```sh
python -m unittest discover -s tests -q
gdlint lantern_game/scripts lantern_game/tests.gd tools/lantern_audit.gd tools/lantern_motion.gd
gdformat --check lantern_game/scripts lantern_game/tests.gd tools/lantern_audit.gd tools/lantern_motion.gd
python tools/capture_lantern.py
python tools/audit_lantern.py
python tools/capture_lantern_motion.py
python tools/package_lantern.py
```

Use `GODOT4_BIN` to select Godot 4.7.2. On this sandbox use `--portable` on all three capture commands; Linux CI uses Mesa/Xvfb. This is **not** a physical GPU FPS benchmark.

## Current results

- **65 Python tests**, GDScript lint/format passed.
- **4759 Godot assertions**: real collisions, 1330 approaches to all 341 trunks, 12 house fronts, connected free-road cells, menus/dialogue/tools/wildlife, plus live silhouette coverage, translation, frame and visibility synchronisation.
- 24 general rendered screenshots here, 152 full-map close-ups in `../lantern-audit/after/`, covering all 430 manifest objects and 1284 painted road cells.
- 48 motion frames / 10 fps GIF in `../lantern-motion/`. Actual Godot input, physics, wind and particles; no generated concept art, no post-production pan.
- Isolated ground-shadow A/B images hide the actual actors, particles and sunlight overlay and stop their physics. Only simulation time changes to demonstrate wind-driven shadow movement independently.
- All three result.json reports must PASS and match the game-source digest before packaging.

## Reading the images honestly

The sunlight is offscreen northwest. Shadows are alpha silhouettes projected onto a common ground plane, not ray-traced light: they do not climb neighbouring facades or stop at another object's volume. All raised sprite objects, characters, current tools, animals, lanterns, flowers and seedlings participate. Flat terrain, atlas-painted ground decoration and water ripples are surfaces, not separate elevated casters. Houses and stones stay rigid; foliage, water, wildlife, characters and airborne leaves animate.

`../lantern-audit/LIGHTING-REVISION.md` records the BEFORE defects and AFTER checks. The older `revision-clean-zip-*` files in this directory belong to historical 0.1.2; the current clean ZIP import/tests are in `../lantern-motion/clean-zip-*.log`.

Project: source ZIP, not an EXE. Open `LanternValley/project.godot`, F5.
