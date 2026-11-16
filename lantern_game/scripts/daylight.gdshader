shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 grade : source_color = vec4(1.0);
uniform float night = 0.0;
uniform float moonlight = 0.0;
uniform float moon_angle = 0.0;
uniform float clock_time = 0.0;
uniform vec4 world_rect = vec4(0.0, 0.0, 640.0, 360.0);
uniform vec2 lamps[7];
uniform float powers[7];

void fragment() {
    vec3 original = texture(screen, SCREEN_UV).rgb;
    vec2 p = world_rect.xy + UV * world_rect.zw;
    float pool = 0.0;
    float core = 0.0;
    for (int i = 0; i < 7; i++) {
        vec2 d = (p - lamps[i]) / vec2(1.0, 0.78);
        float distance_to_light = length(d);
        float flicker = 0.97 + 0.03 * sin(clock_time * 3.0 + float(i) * 2.4);
        pool += pow(max(0.0, 1.0 - distance_to_light / 72.0), 2.0) * powers[i] * flicker;
        core += pow(max(0.0, 1.0 - distance_to_light / 13.0), 2.0) * powers[i];
    }
    vec3 dark = original * grade.rgb;
    vec3 warm = original * vec3(1.12, 0.94, 0.69);
    vec3 color = mix(dark, warm, clamp(pool * night * 1.7, 0.0, 0.88));
    color += vec3(0.95, 0.47, 0.12) * core * night * 0.28;
    // The moon path is emitted AFTER the night grade, and bounded to lake water.
    if (p.x > 1200.0 && p.x < 1260.0 && p.y > 536.0 && p.y < 642.0) {
        float row = floor((p.y - 536.0) / 5.0);
        float width = mix(3.0, 12.0, (p.y - 536.0) / 106.0);
        float center = 1230.0 + cos(moon_angle) * 10.0 + sin(row * 1.9 + clock_time * 0.6) * 7.0;
        float ripple = 1.0 - smoothstep(0.6, 1.3, abs(mod(p.y - 536.0, 5.0) - 2.5));
        float path = 1.0 - smoothstep(width * 0.3, width, abs(p.x - center));
        float ends = smoothstep(536.0, 550.0, p.y) * (1.0 - smoothstep(615.0, 642.0, p.y));
        color += vec3(0.20, 0.28, 0.35) * ripple * path * ends * night * moonlight * 0.55;
    }
    // Soft, low-amplitude edge atmosphere; no blur or extra viewport passes.
    float vignette = smoothstep(0.25, 0.85, length(UV - vec2(0.5)));
    color *= 1.0 - vignette * night * 0.12;
    COLOR = vec4(color, 1.0);
}
