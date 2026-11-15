# Performance investigation — v0.3.1

## Confirmed CPU regression, not the whole 22 FPS diagnosis

The v0.3 animation path evaluated the full AnimationPlayer and `seek(..., true)` on two auxiliary players, then overwrote both auxiliary skeletons with the full-body result. It also did this with the FPS meshes hidden. The revised path evaluates the source once, copies the output only in first person, disables the auxiliary evaluators, and disables hidden-arm IK.

`perf-before.log` / `perf-after.log`: local **headless CPU animation-only microbenchmark**, seven batches × 500 advances, median per advance:

| Camera | Before | After |
|---|---:|---:|
| Third person | 335.256 μs | 99.912 μs |
| First person | 338.332 μs | 116.942 μs |

This does **not** time a rendered game frame, the IK callback or RX 580. Saving ~0.2 ms is real but does not account for a ~45 ms delivered frame at 22 FPS. Reproduce with `godot --headless --path forest_game --script res://animation_benchmark.gd -- --self-test`. Clock speed / host load vary.

## GPU cost candidates and changes

Previous High still used 4096 directional shadows, PCSS via `light_angular_distance=0.8`, blended cascades, and MSAA 2× on top of FXAA. New High uses 2048 shadows, PCF, no cascade blend, FXAA alone and lower-cost half-resolution SSAO; forest/hero/grass shadows remain. Ultra is retained as an expensive explicit option. Trees and grass were not deleted to produce the result.

Tree meshes/LODs are now shared per source mesh across spatial cells, and cell transforms are local to their centers so distance/LOD controls work spatially. Inactive effect pools disable processing. These are cost reductions, not proof of the user's limiting subsystem.

## Real-device diagnosis

`performance_diagnostic.gd` runs 12 fixed-camera, uncapped A/B variants: current settings, reconstructed old High, old High without PCSS, old High without MSAA, half-resolution, no post-processing, no shadows, no trees, no grass, frozen animation, no VFX, baseline repeat. It reports wall-clock mean/p99 intervals, available GPU/render-CPU timings, animation CPU cost, draw calls and primitives, hardware/configuration and a drift warning. Each stage starts from the same configuration; previous ablations do not accumulate. It restores settings after completion/cancellation.

A lack of FPS change when switching **grass shadows** off is not a measurement of removing all grass. Both shadows and entire grass draw geometry can now be isolated, but grass is not assumed guilty.

The software-Vulkan CI A/B report is stored in `../forest-game/performance-ab.json` when validation completes. Its frame-limited sampling is for regression/evidence, not an RX 580 FPS prediction. The `legacy_*` stages reconstruct GPU settings in the current executable; they are not a binary benchmark of v0.2.

## Official guidance used

- [GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html): distinguish CPU/driver and GPU bottlenecks; ablate resolution, shadow maps and effects, reuse resources.
- [Lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html): directional shadow distance and atlas/filter size trade cost against quality; PCSS/soft shadows are not free.
- [Resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html): 0.5 scale is one quarter of the pixels, not half; no gain means the bottleneck may be elsewhere.

On physical RX 580 / the user's CPU: **not yet measured**. A user report from `user://performance-diagnostic.json` is required to confirm the actual bottleneck there.

## Completed rendered A/B evidence

[Validation run 43752469497](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43752469497), game source `99938eb2119578ff50e2e0483ecfcac9cd7f4ad1`: **47 gameplay checks**, **22 real Forward+ screenshots**, all **12 rendered diagnostic stages** completed. New High screenshot and graphics menu were opened and inspected, together with representative third-/first-person frames. A fresh source ZIP extraction also passed import and all 47 checks (logs here).

Environment: llvmpipe LLVM 20.1.2 / software Vulkan, 1280×720, first-person fixed view. Not AMD RX 580.

| Variant | Mean delivered frame ms | Draw calls | Primitives |
|---|---:|---:|---:|
| Optimized High baseline | 1006.88 | 541 | 653304 |
| Reconstructed old High GPU settings | 1692.55 | 541 | 665870 |
| Old High, PCSS off only | 1588.01 | 541 | 665870 |
| Old High, MSAA off only | 1674.87 | 541 | 665870 |
| Optimized High, half-resolution | 665.79 | 541 | 653304 |
| Optimized High, post off | 816.63 | 541 | 653304 |
| Optimized High, shadows off | 673.48 | 250 | 270369 |
| Optimized High, trees off | 401.16 | 273 | 257682 |
| Optimized High, grass off | 935.82 | 387 | 571689 |
| Optimized High, animation frozen | 1011.19 | 541 | 653304 |
| Optimized High, VFX off | 1011.53 | 541 | 653304 |
| Optimized High baseline repeat | 1014.15 | 541 | 653304 |

The new High stack reduces delivered frame cost by ~40.5% versus reconstructed old High **in this software-rendered scene**. Individual PCSS/MSAA ablations alone are not the whole gain; the combined shadow atlas/filter/cascade/SSAO/AA changes matter. Trees and shadows dominate these ablations; removing all grass saves ~7%, freezing animation does not help rendered throughput here. The ablations overlap (removing trees also removes their shadows), so savings cannot be added together. These numbers do not imply 22→37 FPS or any other prediction on the user's GPU.

Baseline repeat differs by <1%, so this run's drift flag is stable. GPU timestamps are available here, but their asynchronous scope is not identical to wall-clock delivered frame intervals; use the raw JSON with that distinction. The report on the user's actual machine is still required to confirm that machine's limiting path.
