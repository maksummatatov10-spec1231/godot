> **Текущая 0.1.6:** [Новые звери, удаление овалов и привязка теней](../lantern-audit/CONTACT-WILDLIFE-REVISION.md). Старые численные результаты ниже исторические; PNG и `result.json` обновлены полным прогоном для 0.1.6.

# Lantern Valley · 0.1.4 · actual-render evidence

> **0.1.5 — текущая версия:** [Оптимизация и замеры](../lantern-performance/PERFORMANCE.md). Полный pipeline повторён; тени локальны камере, приём фасадами и героем сохранён. [Релиз 0.1.5](https://github.com/maksummatatov10-spec1231/godot/releases/tag/lantern-valley-v0.1.5).

This directory now contains the **lighting/motion revision**, not the historical 0.1.2 renders.

## Reproduce

```sh
python -m unittest discover -s tests -q
gdlint lantern_game/scripts lantern_game/tests.gd tools/lantern_audit.gd tools/lantern_motion.gd
gdformat --check lantern_game/scripts lantern_game/tests.gd tools/lantern_audit.gd tools/lantern_motion.gd
python tools/capture_lantern.py
python tools/audit_lantern.py
python tools/capture_lantern_motion.py
python tools/capture_lantern_beauty.py
python tools/package_lantern.py
```

Use `GODOT4_BIN` to select Godot 4.7.2. On this sandbox use `--portable` on all three capture commands; Linux CI uses Mesa/Xvfb. This is **not** a physical GPU FPS benchmark.

## Current results

- **70 Python tests**, GDScript lint/format passed.
- **5892 Godot assertions**: real collisions, 1330 approaches to all 341 trunks, 12 house fronts, connected free-road cells, menus/dialogue/tools/wildlife, plus live silhouette coverage, translation, frame and visibility synchronisation.
- 24 general rendered screenshots here, 152 full-map close-ups in `../lantern-audit/after/`, covering all 430 manifest objects and 1284 painted road cells.
- 48 motion frames / 10 fps GIF in `../lantern-motion/`. Actual Godot input, physics, wind and particles; no generated concept art, no post-production pan.
- Isolated ground-shadow A/B images hide the actual actors, particles and sunlight overlay and stop their physics. Only simulation time changes to demonstrate wind-driven shadow movement independently.
- All four result.json reports must PASS and match the game-source digest before packaging.

## Reading the images honestly

The sunlight is offscreen northwest. Ground shadows use alpha silhouettes; elevated surfaces use a shared light-depth comparison, so facades/crowns/characters receive shadows from other sprites. Height comes from the billboard foot, not full 3D mesh geometry. All raised sprite objects, characters, current tools, animals, lanterns, flowers and seedlings participate. All raised sprites now RECEIVE shadows as well, using shared static/moving light-depth maps. Flat terrain, atlas-painted ground decoration and water ripples are surfaces, not separate elevated casters. Houses and stones stay rigid; foliage, water, wildlife, characters and airborne leaves animate.

`../lantern-audit/RECEIVER-REVISION.md` records the BEFORE defects and AFTER checks. The older `revision-clean-zip-*` files in this directory belong to historical 0.1.2; the current clean ZIP import/tests are in `../lantern-beauty/clean-zip-*.log`.

Project: source ZIP, not an EXE. Open `LanternValley/project.godot`, F5.

## Requested still images

Five clean 1280×720 player-visible PNGs are in `../lantern-beauty/`: village, forest, farm, facade reception, hero with wildlife. A sixth reception-disabled image is diagnostic, excluded from the five-picture download. [0.1.4 release](https://github.com/maksummatatov10-spec1231/godot/releases/tag/lantern-valley-v0.1.4) includes the picture bundle. All four current reports PASS and match. Normal Mesa full publishing run: [43805294777](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43805294777). The private legacy portable SwiftShader exit is still a failed diagnostic, not silently accepted.
