shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float bend = 0.07;
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(TIME*1.35+world.x*0.6+world.z*0.45)+sin(TIME*2.1+world.z)*0.25;
 VERTEX.x+=sway*bend*max(VERTEX.y,0.0);
}
void fragment() {
 vec4 color=texture(albedo_tex,UV)*tint;
 ALBEDO=color.rgb; ALPHA=color.a; ALPHA_SCISSOR_THRESHOLD=0.45;
 ROUGHNESS=0.85;
 BACKLIGHT=color.rgb*0.24;
}
