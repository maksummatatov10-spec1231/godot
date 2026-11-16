# Foundation audit — recorded before implementation, 2026-11-15

## Observed defects / missing systems

1. Menu always offers entry/resume, with no persistent game save or Continue/New Game distinction. Only settings use user://.
2. No first-run prologue, skip/replay flow, overwrite confirmation or durable intro completion.
3. Lighting is static warm daylight; no clock, dawn/dusk, moon, night readability or nighttime light pools. Existing beacon glow is only faint drawn circles, not illumination.
4. Original procedural art identified from build_lantern_map.py/CREDITS: fox/rabbit; dock/link; soil beds; fences/endcaps/posts; crates; fountain; stall counter/produce; lantern; seedling. Other world textures are source atlas crops/assemblies, not original drawings. Existing original audio is not a texture.
5. Preserve actual roads/map/physics, tree alpha-foot contacts, four-direction animation, local shadow budgets, no ground ellipses. Regenerate original drawing code and its outputs without changing source Ninja Adventure originals.
6. Esc lacks save/status/autosave settings. Writes need error feedback, bounded validation, recoverable backup, crash-aware temp writes; malformed/out-of-bounds saves cannot teleport into water/solids. Test data must not overwrite a user's live slot.
7. UI panels at 640x360 have limited space: separate full settings page required rather than appending controls beyond bottom edge.
8. Existing tests/captures assume main-menu first button immediately plays. Update intentional new-player flow, keeping deterministic test/capture clock and isolated save paths; no stale rendered reports passed off as current.

## Implementation / verification plan

Record audit → redraw originals with coherent palette/shape/key poses → independent clock and save modules → day/night lighting/prologue/menus → strict import + gameplay/persistence tests → actual-render UI/time/animation/collision screenshots → record all observed image defects → fixes and repeat → fresh project ZIP only after matching current evidence. No new story quests/bosses in this foundation task.

## Research consulted

- Godot user:// paths and platform-specific persistence: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html
- Godot saving games: https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html
- Godot 2D lighting/shadows: https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
- Pixel animation: key/contact/passing poses, restrained idle, onion-skin consistency: https://www.pixelbook.io/blog/how-to-animate-pixel-art-sprites and https://pixnote.net/en/learn/animation/
- Day/night reference using CanvasModulate plus local light: https://godotengine.org/asset-library/asset/836 (Godot 3 reference, not imported code).

No Undertale art/music/story copied. Use original prose and illustration; retain familiar Z-confirm/X-reveal/C-menu interaction.
