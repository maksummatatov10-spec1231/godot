shader_type spatial;
render_mode diffuse_burley;
uniform vec4 moss : source_color = vec4(0.13, 0.23, 0.095, 1.0);
uniform vec4 earth : source_color = vec4(0.29, 0.21, 0.12, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y); }
varying vec3 wp;
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float path_x=2.4*sin(wp.z*0.055);
 float trail=1.0-smoothstep(1.5,3.0,abs(wp.x-path_x));
 float grain=noise(wp.xz*19.0);
 float patch=noise(wp.xz*0.3)*0.5+noise(wp.xz*1.4)*0.3+0.2;
 ALBEDO=mix(moss.rgb*(0.65+patch*0.7),earth.rgb*(0.8+grain*0.4),trail);
 ROUGHNESS=0.92;
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.13,0.5+(noise(wp.zx*17.0)-0.5)*0.13,1.0);
}
