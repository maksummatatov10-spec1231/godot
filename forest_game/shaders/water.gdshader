shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
varying vec3 wp;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; VERTEX.y+=sin(wp.x*1.4+TIME)*0.018; }
void fragment(){
 float ripple=sin(wp.x*7.0+wp.z*3.0+TIME*1.5)*sin(wp.z*9.0-TIME*1.7);
 ALBEDO=mix(vec3(0.035,0.16,0.15),vec3(0.18,0.37,0.28),ripple*0.5+0.5);
 METALLIC=0.35; ROUGHNESS=0.17;
 NORMAL_MAP=vec3(0.5+sin(wp.x*8.0+TIME)*0.09,0.5+cos(wp.z*9.0+TIME)*0.09,1.0);
}
