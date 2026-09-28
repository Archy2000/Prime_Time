shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D splat:source_color,filter_linear;
uniform float age=0.0;
uniform float lifetime=6.0;
uniform float seed=0.0;
uniform sampler2D wave_field:filter_linear,repeat_disable;
uniform vec2 field_origin=vec2(-72.0,-88.0);
uniform float field_extent=144.0;
void vertex(){
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=texture(wave_field,(world.xz-field_origin)/field_extent).r;
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
    float t=clamp(age/lifetime,0.0,1.0);
    vec2 p=UV-0.5;
    vec2 drift=vec2(noise(UV*4.0+seed+age*0.16),noise(UV*4.0-seed-age*0.13))-0.5;
    vec2 uv=UV+drift*0.14*smoothstep(0.0,0.45,t);
    float r=0.015+0.085*smoothstep(0.0,0.7,t);
    float ink=texture(splat,uv).a*0.28;
    ink+=(texture(splat,uv+vec2(r,0)).a+texture(splat,uv-vec2(r,0)).a+texture(splat,uv+vec2(0,r)).a+texture(splat,uv-vec2(0,r)).a)*0.18;
    float cloud=exp(-dot(p+drift*0.25,p+drift*0.25)*11.0)*(0.65+0.35*noise(UV*6.0+seed+age*0.12));
    float density=mix(ink,cloud,smoothstep(0.0,0.5,t));
    float edge=1.0-smoothstep(0.32,0.5,max(abs(p.x),abs(p.y)));
    ALBEDO=mix(vec3(0.40,0.035,0.025),vec3(0.32,0.13,0.105),t);
    ALPHA=density*edge*0.70*exp(-age*0.32)*(1.0-smoothstep(0.65,1.0,t));
}
