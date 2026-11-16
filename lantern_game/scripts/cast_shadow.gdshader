shader_type canvas_item;
render_mode unshaded;
uniform float crown_height = 32.0;
uniform float feet_local_y = 0.0;
global uniform float wind_time;
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
}

void fragment() {
    float silhouette = texture(TEXTURE, UV).a;
    COLOR = vec4(0.075, 0.12, 0.18, silhouette * 0.38);
}
