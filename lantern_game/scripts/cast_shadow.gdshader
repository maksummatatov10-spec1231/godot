shader_type canvas_item;
render_mode unshaded;
uniform float crown_height = 32.0;
uniform float feet_local_y = 0.0;
global uniform float wind_time;
global uniform vec4 shadow_light;
uniform bool wind = false;

void vertex() {
    // Identical local deformation to foliage.gdshader, BEFORE ground projection.
    if (wind) {
        float phase = (MODEL_MATRIX * vec4(0.0, feet_local_y, 0.0, 1.0)).x * 0.15;
        float height_weight = clamp((feet_local_y - VERTEX.y) / max(crown_height, 1.0), 0.0, 1.0);
        float breeze = sin(wind_time * 1.7 + phase) * 1.25
            + sin(wind_time * 0.63 + phase * 0.7) * 0.65;
        VERTEX.x += breeze * height_weight * height_weight;
    }
    // MODEL_MATRIX still holds the cached baseline transform. Recover its foot
    // and signed height, then apply today's solar/lunar ground displacement.
    vec2 foot = (MODEL_MATRIX * vec4(0.0, feet_local_y, 0.0, 1.0)).xy;
    vec2 baseline = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    float height = (baseline.y - foot.y) / 0.48;
    vec2 projected = baseline + (shadow_light.xy - vec2(0.85, 0.48)) * height;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(projected, 0.0, 1.0)).xy;
}

void fragment() {
    float silhouette = texture(TEXTURE, UV).a;
    if (shadow_light.w > 0.01) {
        vec2 pixel = TEXTURE_PIXEL_SIZE;
        float nearby = texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a
            + texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a
            + texture(TEXTURE, UV + vec2(0.0, pixel.y)).a
            + texture(TEXTURE, UV - vec2(0.0, pixel.y)).a;
        silhouette = mix(silhouette, silhouette * 0.6 + nearby * 0.1, shadow_light.w);
    }
    COLOR = vec4(0.075, 0.12, 0.18, silhouette * shadow_light.z);
}
