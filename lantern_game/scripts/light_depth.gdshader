shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Rows are submitted in ascending LIGHT height. Transparent texels discard instead
// of erasing a taller opaque texel. Two maps keep static/dynamic ordering separate.
global uniform float wind_time;
global uniform vec4 shadow_light;
uniform bool clip_enabled = false;
uniform vec4 clip_rect = vec4(0.0);
varying vec2 world_q;
varying float light_height;

void vertex() {
    float height = COLOR.r * 128.0 - 32.0;
    light_height = max(height, 0.0) / 128.0;
    // Reproject immutable baseline strips on the GPU: no clock-keyed CPU mesh rebuild.
    VERTEX += (shadow_light.xy - vec2(0.85, 0.48)) * height;
    float phase = COLOR.g * 6.28318530718;
    float slow_phase = COLOR.b * 6.28318530718;
    float breeze = sin(wind_time * 1.7 + phase) * 1.25
        + sin(wind_time * 0.63 + slow_phase) * 0.65;
    VERTEX.x += breeze * COLOR.a;
    world_q = VERTEX;
    // Alpha-contact planes can put strip edges exactly on a depth texel centre.
    // A sub-raster-grid tie-break avoids viewport-size-dependent fill rounding.
    // This affects only the offscreen depth raster, NEVER the visible silhouette.
    VERTEX += vec2(1.0 / 256.0);
}

void fragment() {
    if (clip_enabled && (any(lessThan(world_q, clip_rect.xy)) || any(greaterThanEqual(world_q, clip_rect.xy + clip_rect.zw)))) { discard; }
    // Sample explicit atlas texel centres, including interpolated strip edges.
    vec2 atlas_uv = (floor(UV / TEXTURE_PIXEL_SIZE + vec2(0.001)) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
    if (texture(TEXTURE, atlas_uv).a < 0.5) {
        discard;
    }
    COLOR = vec4(light_height, 0.0, 0.0, 1.0);
}
