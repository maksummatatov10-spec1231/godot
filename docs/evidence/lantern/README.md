# Lantern Valley — first playable evidence

Standalone project: [`lantern_game`](../../../lantern_game/README.md), not `forest_game`.

## Reproduction / source identity

- Successful rendered validation: [Actions 43757038240](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43757038240).
- Gameplay source: **5afbcbbc02e997ffba624ebf66d48392dab68465**; evidence commit **6e99f54**.
  The intervening README-only commit does not change the game.
- `result.json` contains the SHA256 of all standalone source/art/import-settings files.
  `tools/package_lantern.py` refuses packaging if this identity does not match.
- Godot **4.7.2**, Compatibility, 1280×720, Xvfb + software Mesa llvmpipe on CI.
  These are real viewport PNGs, **not mockups and not a physical GPU FPS benchmark**.
- **56 Python tests** (50 existing + 6 new asset regressions), GDScript lint/format,
  **1946 Godot assertions** pass. Of the latter, 1902 check positive geometry/physics
  registration for 951 shapes; the remaining 44 check game/input behavior. They are
  not 1946 independent gameplay scenarios.
- Clean project ZIP was separately extracted into an empty folder, imported and
  passed the same 1946 assertions. Logs: `clean-zip-{import,gameplay}.log`.

## Visual review

The following real renders were opened and inspected after the final CI run:

- `00-map-overview`: all 12 cottages, connected village routes, lake, fenced farm,
  forest ring and forest trails. The zoomed-out overview is a capture camera, not HUD.
- `03-village-collisions`: pink rectangles follow lower cottage walls, pots, benches,
  fountain and stall footprints. Roof overhangs and tree crowns intentionally do not
  become giant impassable rectangles. The green circle is the player's feet collider.
- `05-lake` / `06-lake-collisions`: cyan physical shapes trace the visible cyan-water
  runs of each shoreline tile. The hero is placed on the **land-side jetty**, not in
  the lake. Where branches overlap water, the diagnostic overlay also shows the
  underlying water shape over the branch; this does not mean the crown is a collider.
- `06-farm-collisions`: four rails line up with the fence art, a 48px north gate remains
  free. Crops themselves are passable. Vertical fence art was corrected after an
  earlier screenshot showed disconnected decorative stubs.
- `05-forest`: hero and wildlife on the western trail, foreground tree sorting,
  animated flowers/ripples and leaf particles. Small trunk shapes, not canopies, block.
- `04-traveller`, `07-lantern-ability`, `08-sword`, `10-wildlife-surprise`: readable
  portrait dialogue; visible pulse; a real weapon-layer swing; surprised hero and fox.
- Menu/settings/pause frames are included; no permanent HUD text is drawn during play.

The collision overlay is drawn **from the actual CollisionShape2D nodes**, not a
second approximation. F3 also enables Godot's debug-collision hint. Water footprints
are additionally checked against every underlying image pixel in the Python tests.

## Practical movement / interaction tests

`gameplay.log` records tests that actually hold Input actions for physics frames:
walking across the plaza; approaching a building from front/side; approaching the
south farm fence; walking through the open north gate; approaching the west water
bank and stopping within two pixels of the geometry-derived expected center point.

Other checks cover Z menu activation, frozen player/wildlife on pause, nearby NPC
interaction, gradual text, X reveal including final punctuation, Z page advancement
and exit, lantern cooldown/beacons, five tool textures, four facing directions,
fox fleeing away from the hero, surprise/back-step and fence-occluded line of sight.

Scene captures intentionally position the camera/actors and select animation frames
for reproducible evidence. They are not presented as an uninterrupted human playthrough.

## Limits

No interiors, enemy combat, inventory/harvesting, world progress saves or global
wildlife pathfinding yet. Rectangular house/trunk foot colliders are intentional;
water uses exact pixel-run rectangles. Wildlife/fountain sprites are original small
palette-matched additions, not extra characters falsely attributed to Ninja Adventure.

An earlier simultaneous manual run failed before evidence publication; the parallel
push run passed. Screenshot mode was hardened to avoid starting audio streams at all
and to expose subsequent CI failure details as annotations. The final run above and
clean-ZIP checks pass without script errors, resource leaks or stale evidence.
