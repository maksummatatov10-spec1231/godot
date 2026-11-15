shader_type sky;
uniform vec3 sun_direction = vec3(0.49, 0.53, -0.7);
float hash2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);
}
float cloud(vec2 p) { return noise2(p)*0.55 + noise2(p*2.04)*0.28 + noise2(p*4.12)*0.12 + noise2(p*8.21)*0.05; }
void sky() {
 float elevation = max(EYEDIR.y,0.0);
 vec3 blue = mix(vec3(0.48,0.69,0.85),vec3(0.045,0.23,0.52),pow(elevation,0.45));
 vec2 uv = EYEDIR.xz / max(elevation,0.08) * 1.5 + vec2(5.3,9.7);
 float density = cloud(uv);
 float coverage = smoothstep(0.49,0.66,density) * smoothstep(0.02,0.18,elevation);
 vec3 cloud_color = mix(vec3(0.60,0.69,0.79),vec3(1.0,0.98,0.92),smoothstep(0.48,0.74,density));
 vec3 color = mix(blue,cloud_color,coverage*0.94);
 float cosine = clamp(dot(normalize(sun_direction),EYEDIR),0.0,1.0);
 // Finite visible disk + soft aureole. Explicit direction matches the shadow sun.
 float disk = smoothstep(cos(0.012),cos(0.009),cosine);
 float halo = pow(cosine,90.0)*0.25 + pow(cosine,8.0)*0.035;
 color += vec3(1.0,0.79,0.47)*(disk*2.0+halo*0.3)*(1.0-coverage*0.7);
 COLOR = EYEDIR.y < 0.0 ? mix(vec3(0.13,0.20,0.15),color,exp(EYEDIR.y*16.0)) : color;
}
