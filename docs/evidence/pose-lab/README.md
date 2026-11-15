# Pose Lab evidence

Browser WebGL/Three.js screenshots, **not Godot Forward+ renders**. Captured with Playwright/Chromium at 1440×900 after implementation `c8a7b6a`, using the actual hero/derived arms/sword assets and saved `combat_pose.json`.

Eight separate frames: palm close-up, third-person A, FPS idle/A/B/C/walk/jump. `browser-errors.json` is empty. `sampling-checks.json` samples all 14 clips, advances elsewhere then returns to 0.3 seconds: max difference across all output bone matrices is 0 for each clip. Source animation is evaluated in an untouched skeleton, then copied before IK; modifying rendered bones never feeds back into the next sample.

Images were opened and inspected. A/B/C are distinct; the handle now meets the upper grip under the guard. **Visual acceptance is partial:** C still shows an unnatural cuff/wrist fold, idle/landing can place hands too low. Deterministic sampling and green tests do not establish anatomically perfect animation. This is why the release is a preview.

Reproduce from `model_lab`: `npm ci`, run dev server on 5173, then `node capture.mjs`. On the Arena Linux sandbox use the locally bootstrapped NSS libraries through `LD_LIBRARY_PATH`; the files are not part of the shipped project.

Clean ZIP check: a fresh extraction passed Godot import and all 38 gameplay checks (`zip-import.log`, `zip-tests.log`). Its included lab was started on a separate port and verified in Chromium: all 14 clips, camera controls, transform gizmo, bone reset, PNG download and rejection of invalid pose JSON. No browser exceptions. `node_modules` is excluded from ZIP and blocked from Godot import by `.gdignore`.
