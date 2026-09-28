shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size=2.0;
uniform float dither_strength=0.018;
void fragment(){
    vec2 size=vec2(textureSize(screen_tex,0));
    vec2 uv=(floor(SCREEN_UV*size/pixel_size)+0.5)*pixel_size/size;
    vec3 c=texture(screen_tex,uv).rgb;
    ivec2 p=ivec2(mod(floor(FRAGCOORD.xy/pixel_size),4.0));
    float b=mod(float(p.x*2+p.y*3),4.0)/4.0-0.375;
    c=floor(clamp(c+b*dither_strength,0.0,1.0)*40.0+0.5)/40.0;
    float vig=1.0-0.21*pow(length(SCREEN_UV-0.5)*1.3,2.0);
    COLOR=vec4(c*vig,1.0);
}
