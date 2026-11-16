# PC / Android / analog touch controls — preimplementation audit

User requires simultaneous PC + Android deliveries, two source ZIPs and an installable APK in GitHub Releases every release, Full HD / target75 FPS on PC, comfortable landscape on phones, real analog joystick (NOT D-pad), configurable control placement/size, and optional auto-run.

Baseline 0.3.0 / 1759435:
- One source ZIP, no Android export preset/build/signature/APK verification pipeline.
- Desktop window1280x720; logical pixel-art viewport640x360. No FPS profile, phone render budget, safe-area handling or lifecycle pause/save.
- Keyboard-only movement; X/Z/C context controls exist but no analog input, pointer ownership, multitouch or layout editor.
- Existing settings column already fills the screen; adding controls directly would overflow. Add a separate screen/control settings panel and dedicated layout editor.
- Existing local-shadow/cache/real-render/collision gates must remain. FullHD is physical output; the pixel-art world retains its intended logical framing, not an enlarged world view.

Plan: shared gameplay and platform-specific export/source profiles; analog vector + radial deadzone (no keyboard-event quantization), independent pointer IDs and explicit release on focus/pause/cancel; movable/resizable touch controls with validated persisted layout/reset/cancel; auto-run applies to movement speed and animation on both platforms. Mobile uses low-resolution 2D viewport upscaling, local depth maps and default60 cap; native rendering optional. PC native1920x1080 / target75, configurable VSync/cap. Actual APK export/signature/manifest checks and Android emulator smoke if available; never substitute desktop touch simulation for a real-device test claim.

Release signing: repository integration cannot access Actions secrets (HTTP403); do not expose or commit private signing keys. Investigate a reproducible CI preview-signing cache; clearly distinguish sideload prerelease APK from a production/Play signing setup. No passwords/credentials requested from user.

Record failures before fixing. Final source ZIPs/APK must correspond to passing source digest; do not present historical0.3.0 archive as new build.

First implementation import (before correction): strict INTEGER_DIVISION caught integer vector centering; use explicit floating half-size conversion. GDScript could not infer `shown` through dynamic world properties; type bool explicitly. Lint caught two long UI strings and intentional multi-return hit testing; use narrow script lint exemptions consistent with existing UI scripts.

Analog fixture first run fails hit tests because injected Input.parse_input_event positions are physical-window coordinates, but centers are logical640x360 under the new1920x1080 stretch. Do not change gameplay hit areas to suit the test. Push injected screen events through the viewport with explicit logical-coordinate flag, matching the coordinates delivered to gameplay after Godot's real OS-input transform; verify physics and independent pointers again.

Local acceptance before actual renders/APK: strict-warning import clean; gameplay11961, new analog/layout/auto-run tests40, foundation writer54/reader27, Python82 pass. X-dialogue fixture advances the frozen game UI once after reveal (otherwise it inspected an intentionally unprocessed label). Injected screen events are viewport-local tests, not physical-finger claims. Android smoke additionally requires an ADB OS-level swipe and Back/background/resume against the installed APK. Both source profiles will be packaged from the same verified game; no forked gameplay or disabled mobile shadows. YAML syntax checked with PyYAML (the optional ruamel parser was absent, not an application defect).
