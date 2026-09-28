shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D screen_tex : hint_screen_texture, source_color, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D water_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 shallow_color : source_color = vec3(0.16,0.34,0.32);
uniform vec3 deep_color : source_color = vec3(0.035,0.12,0.13);
uniform float clarity = 0.32;
uniform float refraction_factor = 0.0121;
uniform vec3 player_pos;
uniform float player_speed = 0.0;
varying vec3 world_pos;
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=sin(world_pos.x*1.1+TIME*1.2)*0.018+sin(world_pos.z*1.6-TIME)*0.014;
}
void fragment(){
    vec2 uv=world_pos.xz*0.055;
    vec3 n1=texture(water_normal,uv+vec2(TIME*0.009,TIME*0.005)).rgb*2.0-1.0;
    vec3 n2=texture(water_normal,uv*1.43+vec2(-TIME*0.006,TIME*0.008)).rgb*2.0-1.0;
    vec2 wave=(n1.xy+n2.xy)*0.5;
    float d=texture(depth_tex,SCREEN_UV).r;
    vec4 p=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,d*2.0-1.0,1.0);
    float thickness=max(0.0,-p.z/p.w+VERTEX.z);
    vec2 refracted=clamp(SCREEN_UV+wave*refraction_factor*min(thickness,1.0),vec2(0.001),vec2(0.999));
    float rd=texture(depth_tex,refracted).r;
    vec4 rp=INV_PROJECTION_MATRIX*vec4(refracted*2.0-1.0,rd*2.0-1.0,1.0);
    if(-rp.z/rp.w<-VERTEX.z){refracted=SCREEN_UV;}
    vec3 ground=texture(screen_tex,refracted).rgb;
    float absorption=1.0-exp(-thickness*clarity);
    vec3 tint=mix(shallow_color,deep_color,clamp(thickness*0.18,0.0,1.0));
    vec3 color=mix(ground,tint,absorption*0.85+0.15);
    float glint=pow(max(0.0,1.0-length(wave-vec2(0.08,0.16))*2.7),14.0);
    color+=vec3(0.45,0.48,0.40)*glint*0.5;
    float foam=(1.0-smoothstep(0.02,0.25,thickness))*smoothstep(-0.15,0.5,n1.x+n2.y);
    float dist=length(world_pos.xz-player_pos.xz);
    float wake=(1.0-smoothstep(0.5,3.5,dist))*smoothstep(0.25,0.7,sin(dist*12.0-TIME*9.0))*clamp(player_speed/10.0,0.0,1.0);
    color=mix(color,vec3(0.64,0.67,0.57),clamp(foam*0.55+wake*0.3,0.0,0.65));
    ALBEDO=color;
    ALPHA=1.0;
}
