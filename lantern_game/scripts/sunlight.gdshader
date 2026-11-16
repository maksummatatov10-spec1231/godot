shader_type canvas_item;
render_mode unshaded;

// Celestial canopy light; world-anchored, simulation-time driven.
global uniform vec4 shadow_light;
global uniform float wind_time;
// Live ground-projected silhouettes are drawn below the sorted actors.
void fragment() {
    vec2 p = UV * vec2(1536.0, 1152.0);
    vec2 perpendicular = vec2(-shadow_light.y, shadow_light.x);
    float cross_ray = dot(p, perpendicular / max(length(perpendicular), 0.001));
    float shafts = pow(0.5 + 0.5 * sin(cross_ray * 0.024 + sin(p.y * 0.006)), 9.0);
    float clouds = 0.5 + 0.5 * sin(p.x * 0.008 + wind_time * 0.018) * sin(p.y * 0.011);
    float dapple = smoothstep(0.65, 0.95, sin(p.x * 0.068 + sin(p.y * 0.04)) * sin(p.y * 0.071 + wind_time * 0.08));
    float alpha = 0.022 + shafts * 0.048 + clouds * 0.016 + dapple * 0.025;
    COLOR = vec4(1.0, 0.88, 0.55, alpha);
}
