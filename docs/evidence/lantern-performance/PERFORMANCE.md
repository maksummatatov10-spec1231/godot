# 2D performance revision — inspect/measure BEFORE fixing

Baseline: 0.1.4, commit `15892813fe0437e4739049159ec854c2cd322b4a`, source game SHA `82f209aed2242af0e695676da2cbc37c0112cb79acda2265c5e7987296f954fd`.

## Baseline measurement

Real Godot 4.7.2 headless execution of the unchanged game copied from Git into a separate directory. Same benchmark script, 20 warm-up iterations and 120 samples per view; player walks and animation frames change. Measured ONLY the shadow `_process` CPU work, not full-frame GPU time or the user's FPS.

| View | Shadow CPU median ms | P95 ms |
|---|---:|---:|
| Village | 10.372 | 12.125 |
| Forest | 9.670 | 10.198 |
| Farm | 9.910 | 13.312 |

Initial inspection results: `inspection-before-cpu.json` (the repeatable runner writes new samples into `before-cpu/benchmark.json`). This confirms a significant CPU regression in the new shadow implementation independently of grass rendering.

## Defects recorded BEFORE game changes

- P01: two full-world 1536×1152 depth targets redraw continuously (3,538,944 target pixels), even if the camera sees only a fraction of the map or time is paused.
- P02: moving light geometry is recreated every frame for all moving/animated sprites in the WORLD: per-row dictionaries, sorting, source transforms, UV/vertex arrays and new ArrayMesh resources.
- P03: hundreds of unique materials and repeated shader parameter writes: wind time copied into foliage, ground shadows and every receiver; static feet_y is redundantly uploaded too.
- P04: offscreen foliage and particle work is not scoped to the camera. Every frame both leaf passes process all 682 leaf particles, regardless of visibility.
- P05: far-away animals animate, move and run AI/physics every tick even when irrelevant to the player/view.
- P06: no reproducible before/after performance gate; rendering screenshots alone did not establish acceptable performance.

## Research and implementation decisions

Godot recommends profiling actual bottlenecks and measuring again after each change, not guessing [2](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html). Its renderer team specifically demonstrates the CPU cost of recreating mesh/vertex-array resources during animation, and the benefit of updating/reusing data [3](https://godotengine.org/article/rendering-cpu-optimizations/). GPU guidance calls for fewer state changes/draw calls, batching, and culling instead of assuming low-poly/2D art is automatically cheap [1](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html). Global uniforms are designed to update shared environmental effects like wind without setting a uniform on every material [1](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html).

Applied changes:

1. Camera-local depth targets, with a conservative light-space guard band. A caster outside the screen still participates ONLY if its projected shadow can enter the visible receiver area. Avoid shadow popping at screen edges.
2. Spatially tiled, cached static light geometry: no world-sized static mesh traversal on every rendered view and no static geometry rebuilding while walking. GPU wind still animates visible crowns and their shadows.
3. Cull moving casters/receivers, cache their frame geometry, remove per-frame world-wide sorting/allocation, and redraw depth targets only when geometry/camera/time actually changes.
4. Shared material variants and shared global wind/crop parameters; derive receiver feet from model transform + fixed offset instead of uploading every static object's feet each frame.
5. Camera-local particles, animation work and distant wildlife sleep with a wake-up margin. Do NOT remove visible wildlife/leaves, lower art resolution, disable all shadows or remove offscreen wall/water/tree colliders.
6. Preserve facade/character shadow reception and ordinary animation/controls. Test viewport boundaries, offscreen casters, teleport/zoom changes, pause, tools, physics and images.
7. Same-scene CPU benchmarks before/after and a separate normal Mesa rendered comparison. Software-renderer measurements are NOT a physical RX 580 benchmark or a universal FPS promise.

Not blindly applied: switching to Vulkan/Forward+, forcing texture compression on tiny pixel sprites, reducing world collision fidelity, hiding the problem by disabling grass, reducing all graphics quality, multithreading scene-tree mutations, or implementing GPU particle systems without evidence they remain a bottleneck after culling. Those approaches have trade-offs or change correctness/quality; “all possible methods” includes mutually incompatible techniques. Apply and verify the ones relevant to this game.

## Implementation and regression checks

Implemented P01–P05. The main window remains native-resolution `canvas_items`; all original art and collision shapes remain. The atlas is retained, depth rows remain height-sorted, and received shadows still sample static AND moving blockers. Only a camera-local light region is rendered; static tiles are built on first use and cached, dynamic templates are retained for unchanged poses. One global wind update replaces material-by-material updates; 561 receivers use eight shared variants, ground shadows seven.

Actual Godot import, external-driver parsing, strict lint/format, and 6,417 physics/gameplay/locality assertions pass. New assertions include camera teleport/zoom, offscreen casters that reach the screen, receiver heights up to 80px, cached mesh RID retention, pause/no rebuild, far-wildlife sleep/wake and preserved colliders. Offscreen hidden ground silhouettes intentionally do NOT copy invisible atlas frames every tick; when relevant, they sync to the current source before drawing. Existing tests were updated to assert this visible behavior, not force the old whole-world work.

First portable rendered local/reference comparison exposed up to 59 differing shadow pixels near exact integer q boundaries: changing texture dimensions changed nearest-sample floating-point rounding. Fixed by sampling explicit light-texel centres with a small boundary epsilon. Repeated six comparisons: **0 changed pixels over RGB12 in each pair**. This includes cameras on either side of a crop boundary. Kept the failed private portable run honest: it generated those images but exited -11 in the known private ANGLE/SwiftShader shutdown path, so it is not used as the canonical passing renderer gate. The normal supported Mesa run is required before packaging.

`tools/benchmark_lantern.py` now reproduces baseline/current CPU and rendered measurements and compares six local/full-world reference image pairs. It rejects missing render markers, errors/leaks, nonzero exits, stale game hashes, lack of at least 2× median shadow CPU improvement, nonlocal targets, or ANY changed shadow pixel over RGB12. Four Python unit tests cover the image-comparison gate itself.

## Canonical final results — released 0.1.5

Full supported Compatibility/Mesa pipeline **PASS** twice:
- Validation: https://github.com/maksummatatov10-spec1231/godot/actions/runs/43850731738
- Publication: https://github.com/maksummatatov10-spec1231/godot/actions/runs/43851180346

The final published run produced the raw `result.json`, `before-cpu/`, `after-cpu/`, `before-rendered/`, `after-rendered/`, and `locality/` evidence beside this report. Timing includes no physical GPU measurement. VMs differ: the earlier validation measured CPU 8.1–8.2 → 0.60–0.70ms and rendered frames 64–65 → 26–29ms; the publication VM's absolute times below are faster on BOTH versions. Compare each paired run, not timings across machines.

| View | Shadow CPU median ms, old → new | CPU speedup | Software-rendered frame median ms, old → new | Draw calls, old → new |
|---|---:|---:|---:|---:|
| village | 5.557 → 0.440 | 12.63× | 45.600 → 19.299 | 2288 → 128 |
| forest | 5.518 → 0.492 | 11.22× | 47.127 → 20.919 | 2282 → 340 |
| farm | 5.517 → 0.412 | 13.39× | 47.097 → 18.729 | 2442 → 237 |

The full-world pair of targets used 3,538,944 pixels. Local targets use **753,664–800,768 pixels** in these scenes: **77–79% fewer**, at the SAME logical pixel density, not low-resolution art. Registered casters remain 561; each view selects ~150 static casters and 6–13 relevant moving casters. Static per-tile geometry stays cached; static targets update for visible wind but stop on a real pause. Visible receivers share 8 material variants, ground silhouettes 7, instead of hundreds of unique materials. Near-camera leaf selection is 55/160/91 emitters for village/forest/farm instead of processing all 682 twice per frame.

### Correctness and visual review

- **74 Python tests; 6,417 actual Godot assertions PASS**, including strict warning handling, real practical movement against water, buildings, gates and **1,330 trunk approaches**, all 12 facades, connected walkable roads, menus, controls and tool/ability animation.
- **24** general rendered views, **152** map-audit close-ups, **48** motion frames plus isolated wind-shadow A/B, and **6** beauty captures PASS. Audit covers every one of 430 placed map objects and all 1,284 authored road tiles.
- **6/6 local-vs-full-world reference pairs: 0 pixels changed over RGB12**, including forest edge, farm, facade and both sides of a crop boundary. Light-space texel-centre sampling prevents rounding changes when the crop moves. Offscreen casters that can affect visible receivers/ground remain eligible.
- Raised shadow A/B remains real: **320 facade pixels and 2,224 hero pixels** change when reception is disabled at the same time/pose/camera. Moving ground shadows remain animated: **3,145 isolated changed pixels**.
- Reopened and visually checked the five canonical 1280×720 clean PNGs (village, forest, farm, facade and wildlife) and the actual village/lake/farm collision overlays after the optimization. Player, tools, animals, leaves, tree-to-tree/facade reception and ground silhouettes are present; there is no rectangular crop seam or disappearing house shadow in these verified views.
- `forest_game/`, map artwork, solid placements and art resolution are unchanged.

### Delivery

- Release: https://github.com/maksummatatov10-spec1231/godot/releases/tag/lantern-valley-v0.1.5
- Standalone Godot source ZIP: https://github.com/maksummatatov10-spec1231/godot/releases/download/lantern-valley-v0.1.5/Lantern-Valley-Godot-Project.zip
- Five clean PNGs: https://github.com/maksummatatov10-spec1231/godot/releases/download/lantern-valley-v0.1.5/Lantern-Valley-0.1.5-Screenshots.zip
- Release/evidence commit: `8feffb5eee59521aca4d124e43b441d44fd1774b`. Game digest: `4be764190f8483e54d9734f2874562096e7d12534bee5e6ae1f4700f3912a995` across all five reports.
- Local repackaged ZIP extracted into a fresh directory: **all 116 source files byte-identical**, fresh import and all **6,417 assertions PASS**, no engine errors/leaks. Details/hash in `clean-zip.json`, logs beside it. GitHub lists all ten published assets; remote release redirect downloads have NOT been independently rehashed in this sandbox. A local ZIP's timestamps can differ from CI's ZIP.

### Remaining limits

This addresses the measured whole-world shadow regression and related repeated script/draw work. It is not a promise of a particular FPS on the user's hardware, nor a claim to have applied every optimization ever invented. Every-frame camera movement may build a newly visited static tile once (then reuse it); a fully zoomed-out view legitimately needs more of the world than a close-up. Visible crowns must still update their animated light maps. The private portable ANGLE/SwiftShader shutdown issue noted above is separate from the normal Mesa renderer, whose strict nonzero/error/leak gates all pass. There is no performance justification here for degrading the art, removing facade shadows, or disabling collisions/grass.
