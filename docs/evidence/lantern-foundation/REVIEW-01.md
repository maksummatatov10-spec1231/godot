# First actual-render inspection — before corrections

Portable ANGLE preview: 21 frames produced, shutdown exit -11 (NOT accepted as release verification). Inspected village noon/night, settings, final intro card.

Recorded defects together before fixes:
1. Night image is identical to daylight except moon: grading layer -1 is behind world canvas. Move grade above world, UI above grade; add numerical day/night and lamp A/B gates.
2. TextureRect size was assigned while still using native-image minimum, before EXPAND_IGNORE_SIZE; artwork stays native-sized and spills across menu / crops intro. Set expand mode before final size, enable clipping.
3. Settings lower controls overflow the viewport due theme button margins. Reduce button-only margins, compact option fonts/layout and assert every focusable rectangle stays inside logical viewport.
4. Need warm illuminated lantern glass and actual scene illumination, not merely a moon overlay. Recheck after grade correction and light A/B.
5. Full-artistry contact sheets must still be inspected at game scale and four directions; new texture generation alone is not approval.

Do not interpret these first images or the crashed preview as PASS. Canonical Mesa CI must exit cleanly.
