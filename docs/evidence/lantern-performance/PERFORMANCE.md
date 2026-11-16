# 2D performance revision — inspect/measure BEFORE fixing

Baseline: 0.1.4, commit `15892813fe0437e4739049159ec854c2cd322b4a`, source game SHA `82f209aed2242af0e695676da2cbc37c0112cb79acda2265c5e7987296f954fd`.

## Baseline measurement

Real Godot 4.7.2 headless execution of the unchanged game copied from Git into a separate directory. Same benchmark script, 20 warm-up iterations and 120 samples per view; player walks and animation frames change. Measured ONLY the shadow `_process` CPU work, not full-frame GPU time or the user's FPS.

| View | Shadow CPU median ms | P95 ms |
|---|---:|---:|
| Village | 10.372 | 12.125 |
| Forest | 9.670 | 10.198 |
| Farm | 9.910 | 13.312 |

Raw results: `before-cpu/benchmark.json`. This confirms a significant CPU regression in the new shadow implementation independently of grass rendering.

## Defects recorded BEFORE game changes

- P01: two full-world 1536×1152 depth targets redraw continuously (3,538,944 target pixels), even if the camera sees only a fraction of the map or time is paused.
- P02: moving light geometry is recreated every frame for all moving/animated sprites in the WORLD: per-row dictionaries, sorting, source transforms, UV/vertex arrays and new ArrayMesh resources.
- P03: hundreds of unique materials and repeated shader parameter writes: wind time copied into foliage, ground shadows and every receiver; static feet_y is redundantly uploaded too.
- P04: offscreen foliage and particle work is not scoped to the camera. Every frame both leaf passes process all 682 leaf particles, regardless of visibility.
- P05: far-away animals animate, move and run AI/physics every tick even when irrelevant to the player/view.
- P06: no reproducible before/after performance gate; rendering screenshots alone did not establish acceptable performance.

## Research and implementation decisions

Godot recommends profiling actual bottlenecks and measuring again after each change, not guessing [2](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html). Its renderer team specifically demonstrates the CPU cost of recreating mesh/vertex-array resources during animation, and the benefit of updating/reusing data [3](https://godotengine.org/article/rendering-cpu-optimizations/). GPU guidance calls for fewer state changes/draw calls, batching, and culling instead of assuming low-poly/2D art is automatically cheap [1](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html). Global uniforms are designed to update shared environmental effects like wind without setting a uniform on every material [1](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html).

Planned applicable changes:

1. Camera-local depth targets, with a conservative light-space guard band. A caster outside the screen still participates ONLY if its projected shadow can enter the visible receiver area. Avoid shadow popping at screen edges.
2. Spatially tiled, cached static light geometry: no world-sized static mesh traversal on every rendered view and no static geometry rebuilding while walking. GPU wind still animates visible crowns and their shadows.
3. Cull moving casters/receivers, cache their frame geometry, remove per-frame world-wide sorting/allocation, and redraw depth targets only when geometry/camera/time actually changes.
4. Shared material variants and shared global wind/crop parameters; derive receiver feet from model transform + fixed offset instead of uploading every static object's feet each frame.
5. Camera-local particles, animation work and distant wildlife sleep with a wake-up margin. Do NOT remove visible wildlife/leaves, lower art resolution, disable all shadows or remove offscreen wall/water/tree colliders.
6. Preserve facade/character shadow reception and ordinary animation/controls. Test viewport boundaries, offscreen casters, teleport/zoom changes, pause, tools, physics and images.
7. Same-scene CPU benchmarks before/after and a separate normal Mesa rendered comparison. Software-renderer measurements are NOT a physical RX 580 benchmark or a universal FPS promise.

Not blindly applied: switching to Vulkan/Forward+, forcing texture compression on tiny pixel sprites, reducing world collision fidelity, hiding the problem by disabling grass, reducing all graphics quality, multithreading scene-tree mutations, or implementing GPU particle systems without evidence they remain a bottleneck after culling. Those approaches have trade-offs or change correctness/quality; “all possible methods” includes mutually incompatible techniques. Apply and verify the ones relevant to this game.

Implementation and after-results pending.
