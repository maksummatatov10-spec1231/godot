# Lantern Valley · 0.1.2 · actual-render evidence

Standalone project: [`lantern_game`](../../../lantern_game/README.md), not `forest_game`.

**The old 0.1.0 overview-only review missed real defects reported by the user.**
It is superseded by the [before-fix defect register and full close-up review](../lantern-audit/REVIEW.md).
The old release remains historical; it is not the corrected download.

## Reproduce

```sh
python -m unittest discover -s tests -q
gdlint lantern_game/scripts lantern_game/tests.gd tools/lantern_audit.gd
gdformat --check lantern_game/scripts lantern_game/tests.gd tools/lantern_audit.gd
godot --headless --path lantern_game --editor --import
godot --headless --path lantern_game --fixed-fps 60 --script res://tests.gd
GODOT4_BIN=godot python tools/capture_lantern.py
GODOT4_BIN=godot python tools/audit_lantern.py
python tools/package_lantern.py
```

- Godot **4.7.2**, Compatibility renderer, CI Xvfb/software Mesa 1280×720.
- **61 Python tests**, lint/format and **3629 Godot assertions**.
- **24 general screenshots** here; **152 close-up frames** in `../lantern-audit/after/`.
- `result.json` identifies the source/art/import settings by SHA256. Packaging requires
  BOTH this successful result and the close-up result to match the current game digest.
- PNGs are actual Godot viewport renders, not generated illustrations or mockups.
- No claimed hardware FPS measurement; software rendering is diagnostic evidence only.

## What is checked

The diagnostic collision overlay comes from actual CollisionShape2D nodes. Tests cover
938 shapes, practical movement into each of 341 trunks (1330 accessible approaches),
every facade, the physical connectivity of 1181 free road-grid cells and all 12 door
approaches, actual stopping at the lake bank, farm fence/gate, pauses, dialogue Z/X,
ability/cooldown, equipment, direction animations and wildlife reactions.

For counts, all-object/road screenshot coverage, visual review and limitations, see
[the detailed review](../lantern-audit/REVIEW.md). Assertions are not independent playthroughs.
Captures intentionally position the actors and camera for reproducible views.

## Delivery

Corrected prerelease: [lantern-valley-v0.1.2](https://github.com/maksummatatov10-spec1231/godot/releases/tag/lantern-valley-v0.1.2).
The ZIP contains the separate source project, not a Windows executable. Open
`LanternValley/project.godot` in Godot 4.7.2 and press F5. Use the SHA256 accompanying
that specific ZIP: a locally rebuilt container can differ because of timestamps.

Old `clean-zip-*` logs from 0.1.0 are historical. Corrected-ZIP validation is recorded
as `revision-clean-zip-*` after repackaging; do not confuse those two sets of evidence.
