> Historical 0.1.6 revision. Current wildlife/contact PNGs beside this report are now regenerated for **0.2.1**. See [foundation release report](../lantern-foundation/RELEASE.md) for the current redraw, checks and delivery. Original 0.1.6 evidence is preserved in its release/source commit.

# Wildlife and shadow-contact revision — defects recorded before fixes

Baseline: 0.1.5, `63cc077`. User crops: image-17.png (rabbit), image-18.png (hero/contact ellipse and gap), image-19.png (tree/shadow gap).

## Confirmed defects

1. Wildlife is placeholder art: the map generator draws 16×16 animals out of a handful of rectangles/ellipses, with only four frames and an alternating one-pixel bob. Sideways rabbit incorrectly inherits the fox-like tail. No distinct idle, walk and flee gaits.
2. `actor.gd::_draw()` STILL invokes `draw_ellipse_shadow()` for EVERY character, on top of the new projected silhouette. The old ellipse is not a reception issue: it is an extra obsolete draw command and must be deleted, including the method.
3. Ground projection uses the physics/sort foot rather than the opaque sprite's actual contact pixels. Hero idle frames have last opaque row at source Y23; with sprite origin at -10 and a 32px frame, the lowest visible pixel centre is Y=-2.5 relative to the actor. Projecting about Y=0 sends that pixel ~2.1px right and 3.7px away from its source along the projection difference. Some trees end at row30 in a 32px crop, leaving transparent padding at the nominal sort foot. A compensating universal offset is therefore not correct.
4. Idle breathing scales around the sprite centre. The foot moves away from the nominal anchor while old shadow and depth passes use the unscaled physical base.
5. Independent pixel snapping of sprite/shadow transforms can round mathematically matching world anchors differently at fractional actor/camera positions.

## Required fix and checks

- Replace placeholder wildlife with detailed quadruped sprites and genuinely articulated locomotion/idle cycles, four directions, slower walk and distinct faster flee motion. Do not merely enlarge old 16px placeholders or linearly blend whole frames.
- Remove the old actor ellipse completely; do not replace it with another contact blob.
- Cache opaque contact data per texture/frame; share the SAME transformed contact plane between projected ground silhouettes, receiver shader and both light-depth passes. Keep physics/collision/sorting unchanged. Handle atlas frames, flips, scale/breathing, trees, props and tools consistently; transparent padding must not detach a caster.
- Preserve the camera-local shadow optimization. No per-frame CPU image readbacks/scanning, no return to full-world UPDATE_ALWAYS targets.
- Check real renders close up, all directions/gaits, fractional positions and several camera zooms; retain full map/physics/reception/locality/performance gates. Produce clean PNGs and actual motion evidence, not a concept illustration.

## Implementation before canonical rendered recheck

- Replaced the 64×64 placeholder sheets with original 384×384 sheets: 32px cells, **12 distinct locomotion poses in all four directions**, separate idle/walk/bounding rows, articulated knees/ankles, moving tail, shaded coat, cream muzzle/cheek ruff, eyes/blink and independently flexing ears. Rabbit has a round haunch, short forelegs, round cheek, long pink-lined ears and a small pompom, not a recoloured fox. Original reproducible art builder: `tools/build_lantern_wildlife.py` (CC0). Researched existing free art, but none of the inspected external sprites was incorporated.
- Walk/bound phases advance by actual distance after collision resolution, not a free-running animation clock. Walking stride14px, bounding stride28px; blocked wildlife does not keep sliding through its pose cycle. Idle blinking uses its own clock.
- Deleted obsolete ellipse draw call AND method, no replacement blob.
- Cached alpha contact per frame/texture/offset; source metadata avoids recomputing cache keys on every shadow pass. Ground projection, light-space row mesh, receiver and wind use the same transformed alpha-contact plane. Held tool uses its body's plane, not the tool tip.
- All characters breathe/animate about planted feet at actorY−3, without changing collisions/sorting. Disabled independent transform snapping to avoid one-item rounding at fractional positions; nearest texture filtering remains.
- Fixed a zero-sized initial flower atlas region uncovered by the contact scan. Initial animation frame is now valid BEFORE registration.
- Updated translation test to synchronize the current pose before its baseline snapshot; it still verifies exact translation, not a relaxed tolerance. Added exhaustive static contact checks and four-direction/three-gait/twelve-phase fractional-position tests, including tool/breathing. **11,988 actual Godot assertions pass**, plus Python art/motion/absence-of-ellipse regressions.
- New rendered driver captures four direction portraits, 24 real rendered frames each of idle/walk/bound and a fractional-position tree closeup, with strict marker/error/exit/hash and independent animal-ROI motion checks. These are articulation/contact evidence; real gameplay movement remains tested separately by the existing motion driver.

## Rendered regression found and fixed before delivery

Both first full runs passed 11,988 physics/contact assertions, 77 Python regressions, normal renders, full-map audit, actual gameplay motion, raised reception A/B and the new 77-frame closeup/motion gate. The strict Mesa locality comparison correctly BLOCKED packaging: 14 forest / 57 facade pixels differed from full-world reference, although private ANGLE comparison was zero. Failures preserved in `lantern-ci-failure/43889157064` and `43889818018`, not marked passed.

Diagnostics: half-pixel alpha-contact planes can place projected row edges exactly on a light-target pixel centre (`0.48*n - 0.26` reaches .5). Tiny viewport projection/fill rounding changes then select a different source texel at a strip edge. Added an explicit 1/256-pixel tie-break ONLY in the offscreen depth raster and explicit atlas texel-centre alpha sampling. The visible ground silhouette and contact anchor are NOT offset, and the zero-difference locality gate is NOT relaxed. Added preservation of benchmark exceptions/raw comparison pairs, since the old failure collector lost subdirectory diagnostics.

## Final canonical verification — 0.1.6

**PASS** supported Compatibility/Mesa validation [43890568763](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43890568763) and independent full publication run [43891272709](https://github.com/maksummatatov10-spec1231/godot/actions/runs/43891272709). All renderer exit codes zero, no engine errors/leaks. Kept failed diagnostics; did not weaken the zero-difference locality gate.

- **77 Python regressions and 11,988 actual Godot assertions PASS**. Alpha contacts covered across static props/trees and animated characters, four directions, three gait groups, twelve phases and fractional world coordinates, plus breathing and the body/tool contact plane. Existing real water/fence/building/trunk movement, pause, controls and ability checks still pass.
- Existing **24 general views, 152 map closeups, 48 gameplay motion frames plus isolated-shadow A/B, 6 beauty captures PASS**. Additional **77 real rendered contact/articulation captures PASS**: 4 direction portraits, 24 frames each idle/walk/bound, 1 tree/prop contact closeup at a fractional camera position. Animation GIFs use 40ms/frame for movement, 80ms for the two-second idle sample; no whole-frame cross-fade.
- **All six local-vs-full-world comparisons: 0 changed pixels over RGB12** after the raster tie-break fix. Includes facade, forest edge, farm, village and both sides of a crop boundary. Ground silhouettes are not shifted by the depth-only tie-break.
- Actual raised reception remains: **327 facade and 2,224 hero pixels** differ in fixed-pose reception A/B. Old actor ellipse function/call is absent, not merely hidden by another sprite.
- Independently opened and visually reviewed the real 1280×720 side/front animal portraits, forest/pine trunk contact closeup and canonical forest wildlife/player view. Rabbit is now crouched with a rounded haunch/short forelegs; fox has a distinct brush tail, muzzle/ruff and articulated paws. Hero and animals have only the directional silhouettes, and the pine/root contacts no longer use the padded crop base. This is pixel-art detail at a new 32px source cell, not photorealistic fur or a resized old 16px placeholder.
- Source art remains original/reproducible; full image sheets have 144 cells each. Collision/art placements in the world manifest and `forest_game/` are unchanged.

### Performance retained (software Mesa, NOT a physical-GPU FPS claim)

Same-scene 0.1.4 baseline vs released 0.1.6, 20 warm-ups and 120 samples per view. The extra contact processing/32px wildlife geometry costs some CPU vs simpler 0.1.5, but remains bounded/cached, and the camera-local optimization is retained. No return to whole-world processing, no per-frame image scans/readbacks, no art-resolution downgrade.

| View | Shadow CPU median ms, 0.1.4 → 0.1.6 | Software rendered frame median ms |
|---|---:|---:|
| village | 7.981 → 1.065 | 62.249 → 26.234 |
| forest | 7.997 → 1.336 | 62.838 → 29.618 |
| farm | 7.990 → 1.090 | 64.002 → 26.495 |

Raw authoritative measurements: `../lantern-performance/result.json`. Global targets still use **753,664–800,768 pixels** in these views, instead of 3,538,944. CPU shadow speedup vs the unoptimized implementation is **5.99–7.49×** on this run. No universal FPS promise.

### Delivery

- [Release 0.1.6](https://github.com/maksummatatov10-spec1231/godot/releases/tag/lantern-valley-v0.1.6), twelve uploaded assets including source ZIP, new side portrait and walk GIF.
- [New real closeup PNG](../lantern-contact/wildlife-direction-3.png), [walk GIF](../lantern-contact/wildlife-walk.gif), [bound GIF](../lantern-contact/wildlife-bound.gif), [tree contact PNG](../lantern-contact/tree-contact-fractional.png).
- Release/evidence commit `7dd1b018b8a5a199d7845d94afb7c6a4d21f2bf2`; all six reports match game SHA `59a71fd1d33870487fc3f39b553dd7a9b4f2b257de97c9fe5585400dccee90ef`.
- Local repackaged ZIP freshly extracted: **117 source files byte-identical**, clean import and all **11,988 assertions PASS**, no errors/leaks. Logs and local archive hash: `../lantern-contact/clean-zip.json`. The remote GitHub ZIP has not been independently downloaded/rehashed in this sandbox; ZIP timestamps can differ between local and CI packaging.

Private portable ANGLE/SwiftShader still intermittently exits -11 at shutdown (as in earlier revisions). Its images are not substituted for passing canonical evidence; both normal Mesa runs above pass strict exits. Artistic preference is subjective; the included new closeups and motion are the actual deliverable for inspection, not a claim that a test can certify “beauty”.
