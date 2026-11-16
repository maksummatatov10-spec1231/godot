# Celestial shadows / illustrated prologue — before implementation

2026-11-15, baseline 0.2.1 / ad49b38. User requests: subtle night shadows; separate generated story pictures with ONE consistent protagonist; continuously moving sun/moon shadows; new game starts in early morning.

Observed baseline limitations:
1. Ground projection constant (-0.85,-0.48); depth projection and receiver lookup hard-code the inverse (0.85,1.48). Changing only the visible ground shadow breaks facade/actor reception.
2. Fixed ground opacity 0.38 and fixed receiver attenuation (0.50,0.59,0.73), unchanged at night. Current night grade darkens shadows but does not reduce their contrast.
3. Camera-local static tiles/pose rows currently bake that fixed projection. Naively rebuilding/reindexing the world every clock tick would regress performance.
4. Clock color interpolation is smooth but has no celestial positions. Moon is a stationary screen accent. New game starts 07:30 rather than predawn.
5. All four story cards use the same valley-memory illustration, cropped into 640x235. No separate scene-to-text illustrations or explicit protagonist reference chain.

Plan: analytic periodic celestial model and continuous light uniforms; GPU-reproject cached, sun-independent geometry; conservative spatial bins/crop margins valid for all bounded solar/lunar angles; time-dependent shadow contrast for BOTH ground and raised receivers; shared alpha-foot anchors/wind preserved. Keep local depth targets and zero-difference local/full gates; add angle/horizon continuity, night-shadow A/B, early-morning start and accelerated real-render orbital sweep tests. Generate one reference-led hero frame, then three different scenes referencing the SAME hero; do not promise perfect automatic identity matching without visual inspection.

Record image/test errors before fixing, then rerun and package only matching passing evidence. No changes to forest_game, world layout or gameplay collisions.

## Implementation review, before corrections
- First headless import exposed Variant-based inference of `time_changed`; fixed with explicit bool, subsequent import + 11,958 gameplay assertions pass.
- Review found moving light target was not refreshed for a changed orbital slope when actors/wind were frozen. Separate slope-dirty from wind-dirty; exercise with frozen-pose renders.
- Moving ground-shadow visibility must use an all-angle envelope rather than the old fixed-angle bounds. GPU-deformed silhouettes need conservative custom culling rectangles.
- Story visual review: four scenes retain moss hood, tan-edged green coat, crossed brown straps, satchel and lantern. Minor generative costume/strap variations remain; use full-frame aspect-fit so the protagonist is not cropped out. These are illustrated AI scenes, not gameplay screenshots.
- Local foundation writer/reader passed, but Mesa capture cannot run here (`xvfb-run` absent); use the canonical Ubuntu/Mesa CI, not the known-crashing ANGLE fallback, for final render acceptance.
- Updating ray tests exposed one more Variant inference in `receiver_pixel`; explicitly typed Vector2. Replaced old fixed-ray source assertion with dynamic-ray assertion; kept both-map/depth/attachment checks.

## Local code acceptance before Mesa render
- Godot 4.7.2 strict-warning import: no compile errors.
- Gameplay/physics: 11,961 assertions, no failures.
- Celestial math: 70,319 assertions across five lunar phases, dense 24-hour sweeps, horizon microsteps and midnight wrapping; all pass. Default/new-game 06:15, daytime reference projection and opposite morning/evening directions verified.
- Full Python regression suite, gdlint and gdformat pass. Numerical tests are not a substitute for actual rendered review below.
- Additional lighting consistency review: decorative sun shafts still used fixed northwest rays and wall-clock shader TIME, while the lake reflection stayed visible regardless of lunar altitude. Align shafts with the celestial direction, use simulation wind_time, and gate/refine lake reflection by the same moon orbit. These are lighting corrections, not new shadow maps.
- UI source review before final render: aspect-fit story leaves transparent side bars, exposing live terrain. Add an opaque full-card backdrop so all four scenes have intentional letterboxing rather than accidental world peeking through.

## Mesa review 01 — run 43941068517
Gameplay, full-map audit, motion, raised reception, wildlife/contact and foundation all pass. The NEW celestial fixture fails its end assertion, not shader compilation: it incorrectly assumes no moving-mesh changes across all hours. Changing the clock also legitimately switches lantern sprite regions at dusk and changes the camera-local selection/crop. Fix the fixture to keep the actual rendered scene, record sweep rebuilds, and separately assert zero pose/mesh rebuilds for continuous clock motion with unchanged poses/selection. Do not weaken local-vs-full pixel equivalence. Fixture assertion previously hung until the 300s timeout; make failures exit explicitly.
- Shader review: Sunshine's custom fragment overwrites COLOR, so explicitly retain incoming COLOR.a before assigning output; otherwise setting the node's celestial fade may be ignored. Attempted to cancel the queued second run; the API refused cancellation, so its outcome is not assumed. A separate canonical run validates the corrected source.

## Actual visual inspection — canonical run 43942598712, before correction
All eight automated gates pass for digest 17139422..., including 24 local/full pairs with zero RGB>12 differences. Inspected the four in-engine story cards, 14-hour sweep/A-B, 24 camera-angle montage, full 08:00 and 14:00 frames, tree contact close-up and lake collision overlay.

**Blocking defect found visually:** at approximately 14:00, houses and tree crowns acquire horizontal self-shadow acne. Both local and full reference contain it, so locality equivalence cannot detect it. The 2D projected depth Jacobian approaches zero for nearly screen-horizontal rays: a half-texel sampling error becomes a large height error. Fixed 1.4–2.4 height bias is insufficient at these angles. Need a continuous slope-scaled raster bias and an isolated-self-caster A/B regression, while retaining facade/hero external reception checks. Do not deliver the otherwise passing ZIP as final.

Other reviewed images: prologue hero fully visible, text legible/no clipping, intentional dark margins; morning long shadows reverse by evening; night shadows subtle; no legacy circular actor shadow in viewed frames; collision water boundary still follows shore. Night/day measured contrast ratio before acne correction is 0.05875, but revalidate on final source.
