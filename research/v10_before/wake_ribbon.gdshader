shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D wave_field:filter_linear,repeat_disable;
uniform vec2 field_origin=vec2(-72.0,-88.0);
uniform float field_extent=144.0;
uniform float water_y=1.15;
uniform float clock=0.0;
uniform bool terrain_clipping=false;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    vec4 f=texture(wave_field,(world_pos.xz-field_origin)/field_extent);
    float ridge=exp(-pow((UV.x-0.43)*5.5,2.0));
    VERTEX.y=water_y+f.r+0.045+ridge*0.13*COLOR.r;
}
void fragment(){
    vec4 field=texture(wave_field,(world_pos.xz-field_origin)/field_extent);
    if(terrain_clipping && water_y+field.r-field.g<0.04)discard;
    float n=noise(vec2(UV.y*5.0-clock*0.55,UV.x*7.0));
    float fine=noise(vec2(UV.y*16.0+clock*0.45,UV.x*19.0));
    float center=0.43+(n-0.5)*0.23;
    float core=1.0-smoothstep(0.055,0.26,abs(UV.x-center));
    float broken=smoothstep(0.24,0.68,n*0.7+fine*0.3);
    float flecks=smoothstep(0.64,0.85,fine)*exp(-pow((UV.x-0.55)*3.0,2.0));
    float edge=smoothstep(0.0,0.15,UV.x)*(1.0-smoothstep(0.75,1.0,UV.x));
    float ridge=exp(-pow((UV.x-0.4)*4.0,2.0));
    float foam=core*(0.35+0.65*broken)+flecks*0.25;
    ALBEDO=mix(vec3(0.15,0.47,0.48),vec3(0.92,0.98,0.96),clamp(foam*1.7,0.0,1.0));
    ALPHA=(ridge*0.08+foam*0.90)*COLOR.a*edge;
}
