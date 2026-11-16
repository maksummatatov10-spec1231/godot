# CONFUSABLE_LOCAL_DECLARATION hotfix — 2026-11-15

- `light_depth.gd`: nested creation variable `tile_mesh` renamed `created_tile`; later cached lookup remains `tile_mesh`. No rendering algorithm/geometry/animation changes.
- Project promotes `confusable_local_declaration` to error (2), just like the previously guarded warning categories. Python regression requires that setting.
- Godot 4.7.2 fresh editor import: exit 0, no script errors. Driver parse: PASS. Godot gameplay: 11,988/11,988 PASS with the required `--fixed-fps 60 --audio-driver Dummy`. Python: 78 PASS. GDScript lint and changed-file format check: PASS.
- An initial test invocation without fixed-fps reported four atlas-frame synchronisation failures; rerun with the repository harness's fixed-fps arguments passed. No assertions were weakened.
- Full graphical/performance evidence was **not regenerated** for this identifier-only fix. Six existing 0.1.6 reports describe the previous game digest, not this hotfix; the release packaging gate remains unchanged and will reject those stale reports for a new full release.
- `artifacts/lantern/Lantern-Valley-warning-fix.zip` contains only `project.godot`, `scripts/light_depth.gd` and patch instructions. Extracted copies were byte-compared with tested source. It is an overlay for the delivered 0.1.6 project, not a new standalone project/release.
- No modifications to `forest_game`, world map or visual assets.
