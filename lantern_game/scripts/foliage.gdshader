shader_type canvas_item;
render_mode unshaded;
uniform float crown_height = 32.0;
global uniform float wind_time;
global uniform vec4 light_rect;
global uniform vec4 shadow_light;

uniform bool wind = true;
uniform bool receive_shadows = true;
uniform float feet_local_y = 0.0;
varying float feet_y;
uniform sampler2D static_depth : filter_nearest, repeat_disable;
uniform sampler2D moving_depth : filter_nearest, repeat_disable;
varying vec2 world_pixel;


void vertex() {
    // Local zero is the trunk foot. The trunk stays planted, the crown bends.
    float phase = (MODEL_MATRIX * vec4(0.0, feet_local_y, 0.0, 1.0)).x * 0.15;
    feet_y = (MODEL_MATRIX * vec4(0.0, feet_local_y, 0.0, 1.0)).y;
    float height_weight = clamp((feet_local_y - VERTEX.y) / max(crown_height, 1.0), 0.0, 1.0);
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
    vec2 q = world_pixel + (shadow_light.xy + vec2(0.0, 1.0)) * height;
    // Sample texel CENTRES: changing crop dimensions must not change nearest
    // rounding on an exact integer light-space boundary.
    vec2 light_uv = (floor(q + vec2(0.0001)) + vec2(0.5) - light_rect.xy) / light_rect.zw;
    float obstruction = max(texture(static_depth, light_uv).r, texture(moving_depth, light_uv).r) * 128.0;
    bool inside = all(greaterThanEqual(light_uv, vec2(0.0))) && all(lessThan(light_uv, vec2(1.0)));
    float visibility = (receive_shadows && inside) ? smoothstep(1.4, 2.4, obstruction - height) : 0.0;
    albedo.rgb *= mix(vec3(1.0), vec3(0.50, 0.59, 0.73), visibility * clamp(shadow_light.z / 0.38, 0.0, 1.0));
    COLOR = albedo;
}
