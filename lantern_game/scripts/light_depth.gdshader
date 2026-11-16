shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Rows are submitted in ascending LIGHT height. Transparent texels discard instead
// of erasing a taller opaque texel. Two maps keep static/dynamic ordering separate.
global uniform float wind_time;
uniform bool clip_enabled = false;
uniform vec4 clip_rect = vec4(0.0);
varying vec2 world_q;
varying float light_height;

void vertex() {
    light_height = COLOR.r;
    float phase = COLOR.g * 6.28318530718;
    float slow_phase = COLOR.b * 6.28318530718;
    float breeze = sin(wind_time * 1.7 + phase) * 1.25
        + sin(wind_time * 0.63 + slow_phase) * 0.65;
    VERTEX.x += breeze * COLOR.a;
    world_q = VERTEX;
}

void fragment() {
    if (clip_enabled && (any(lessThan(world_q, clip_rect.xy)) || any(greaterThanEqual(world_q, clip_rect.xy + clip_rect.zw)))) { discard; }
    if (texture(TEXTURE, UV).a < 0.5) {
        discard;
    }
    COLOR = vec4(light_height, 0.0, 0.0, 1.0);
}
