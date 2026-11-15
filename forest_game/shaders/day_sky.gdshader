shader_type sky;
// Static layered sky clouds: no expensive per-frame radiance rebuild.
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n2(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1)),f.x),f.y);}
float clouds(vec2 p){return n2(p)*0.55+n2(p*2.1)*0.27+n2(p*4.3)*0.12+n2(p*8.5)*0.06;}
void sky(){
 float up=max(EYEDIR.y,0.0);
 vec3 base=mix(vec3(0.64,0.79,0.85),vec3(0.11,0.37,0.59),pow(up,0.5));
 if(EYEDIR.y<0.0){base=mix(vec3(0.16,0.23,0.15),base,exp(EYEDIR.y*12.0));}
 vec2 uv=EYEDIR.xz/max(up,0.12)*0.85+vec2(4.0,12.0);
 float layer=clouds(uv);
 float cover=smoothstep(0.53,0.72,layer)*smoothstep(0.02,0.24,up);
 base=mix(base,mix(vec3(0.67,0.76,0.8),vec3(1.0,0.98,0.91),layer),cover);
 if(LIGHT0_ENABLED){
  float sun=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
  base+=LIGHT0_COLOR*(pow(sun,750.0)*3.0+pow(sun,24.0)*0.12);
 }
 COLOR=base;
}
