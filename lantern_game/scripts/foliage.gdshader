shader_type canvas_item;
render_mode unshaded;
uniform float phase = 0.0;
uniform float crown_height = 32.0;
uniform float wind_time = 0.0;

uniform bool wind = true;
uniform bool receive_shadows = true;
uniform float feet_y = 0.0;
uniform sampler2D static_depth : filter_nearest, repeat_disable;
uniform sampler2D moving_depth : filter_nearest, repeat_disable;
varying vec2 world_pixel;


void vertex() {
    // Local zero is the trunk foot. The trunk stays planted, the crown bends.
    float height_weight = clamp(-VERTEX.y / max(crown_height, 1.0), 0.0, 1.0);
    float breeze = sin(wind_time * 1.7 + phase) * 1.25
        + sin(wind_time * 0.63 + phase * 0.7) * 0.65;
    if (wind) {
        VERTEX.x += breeze * height_weight * height_weight;
    }
    world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec4 albedo = COLOR;
    float height = max(feet_y - world_pixel.y, 0.0);
    vec2 q = world_pixel + vec2(0.85, 1.48) * height;
    vec2 light_uv = q / vec2(1536.0, 1152.0);
    float obstruction = max(texture(static_depth, light_uv).r, texture(moving_depth, light_uv).r) * 128.0;
    bool inside = all(greaterThanEqual(light_uv, vec2(0.0))) && all(lessThan(light_uv, vec2(1.0)));
    float visibility = (receive_shadows && inside) ? smoothstep(1.4, 2.4, obstruction - height) : 0.0;
    albedo.rgb *= mix(vec3(1.0), vec3(0.50, 0.59, 0.73), visibility);
    COLOR = albedo;
}
