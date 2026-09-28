shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float progress=0.0;
uniform vec4 tint:source_color=vec4(0.8,0.96,0.93,0.40);
void fragment(){
    vec2 p=UV*2.0-1.0;
    float r=length(p);
    float angle=atan(p.y,p.x);
    float rough=sin(angle*19.0+progress*7.0)*0.018+sin(angle*37.0)*0.012;
    float ring=1.0-smoothstep(0.01,0.055,abs(r-(0.25+progress*0.62)+rough));
    float breaks=smoothstep(-0.55,0.25,sin(angle*13.0+progress*8.0));
    ALBEDO=tint.rgb;
    ALPHA=ring*breaks*pow(1.0-progress,2.0)*tint.a;
}
