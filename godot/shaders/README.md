# Terrain3D bounded shader derivatives

`terrain_safe_minimum.gdshader` and `terrain_safe_lightweight.gdshader` derive
from the corresponding Terrain3D 1.1.0 examples in
`addons/terrain_3d/extras/shaders/`. Copyright Cory Petkovsek, Roope Palmroos
and contributors; MIT license at `../addons/terrain_3d/LICENSE.txt` applies.

Local changes (2026-11-15):

- Clamp the uniform region-map index before loading it; multiplying its result
  by an out-of-bounds flag does not prevent the load itself.
- Check missing/invalid array-texture layers before height/control texelFetch;
  clamp integer texture coordinates to the actual texture dimensions.
- The lightweight derivative also bounds the region-locations uniform index;
  its returned layer still remains -1 for absent regions.

These are actual Terrain3D vertex/clipmap heightmap shaders, **not a replacement
plane mesh**. The integration fixture uses the bounded lightweight variant,
three mesh LODs, one generated texture layer and a generated two-hill heightmap.
The bounded minimum variant is retained as a simpler untextured diagnostic.
The original addon examples remain unchanged for comparison/upgrades.

This is a restricted lightweight profile, not proof that every optional feature
of the vendor's full shader works on all GPUs. In particular the lightweight
upstream example intentionally omits expensive blending/tessellation features;
see its source comments. CPU Lavapipe is for rendering correctness, not speed
measurements. Do not infer the unique cause of the old crash from this combined
bounds-check/LOD change without an additional bisect.
