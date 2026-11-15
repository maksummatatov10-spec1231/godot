shader_type canvas_item;
render_mode unshaded;
uniform float phase = 0.0;
uniform float crown_height = 32.0;
uniform float wind_time = 0.0;

void vertex() {
    // Local zero is the trunk foot. The trunk stays planted, the crown bends.
    float height_weight = clamp(-VERTEX.y / max(crown_height, 1.0), 0.0, 1.0);
    float breeze = sin(wind_time * 1.7 + phase) * 1.25
        + sin(wind_time * 0.63 + phase * 0.7) * 0.65;
    VERTEX.x += breeze * height_weight * height_weight;
}
