shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D wave_field:filter_linear,repeat_disable;
uniform vec2 field_origin=vec2(-72.0,-88.0);
uniform float field_extent=144.0;
uniform float age=0.0;
uniform float life=2.0;
uniform float radius=1.0;
uniform float height=1.0;
uniform float seed=0.0;
varying float crest;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
    vec2 p=VERTEX.xz/radius;
    float r=length(p),angle=atan(p.y,p.x);
    float ring=0.65+age/life*2.7;
    float teeth=0.62+0.24*sin(angle*9.0+seed)+0.14*sin(angle*17.0-seed);
    crest=exp(-pow((r-ring)/0.30,2.0));
    float rise=sin(clamp(age/0.85,0.0,1.0)*3.14159)*exp(-age*0.7);
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=texture(wave_field,(world.xz-field_origin)/field_extent).r;
    VERTEX.y+=crest*height*rise*teeth;
}
void fragment(){
    vec2 p=(UV-0.5)*8.0;
    float r=length(p),t=clamp(age/life,0.0,1.0);
    float n=noise(p*5.0+vec2(seed,age*1.4));
    float grain=noise(p*19.0-vec2(age*2.0,seed));
    float ring=0.65+t*2.7;
    float band=exp(-pow((r-ring+(n-0.5)*0.22)/(0.18+t*0.24),2.0));
    float foam=band*(0.4+0.6*smoothstep(0.25,0.75,n*0.6+grain*0.4));
    float center=exp(-r*r*1.3)*exp(-age*3.5)*smoothstep(0.30,0.70,grain);
    float water=crest*0.30*(1.0-smoothstep(0.3,1.0,age));
    ALBEDO=mix(vec3(0.22,0.63,0.66),vec3(0.91,0.98,0.97),clamp(foam*1.8+center,0.0,1.0));
    ALPHA=(foam*0.93+center*0.75+water)*(1.0-smoothstep(0.45,1.0,t))*(1.0-smoothstep(3.5,3.95,r));
}
