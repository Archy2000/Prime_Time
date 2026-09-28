shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D screen_tex:hint_screen_texture,source_color,filter_linear;
uniform sampler2D depth_tex:hint_depth_texture,filter_nearest;
uniform sampler2D water_normal:hint_normal,repeat_enable,filter_linear_mipmap;
uniform sampler2D caustics_tex:repeat_enable,filter_linear_mipmap;
uniform sampler2D wave_field:filter_linear,repeat_disable;
uniform sampler2D flow_field:filter_linear,repeat_disable;
uniform float field_resolution=160.0;
uniform vec2 field_origin=vec2(-72.0,-88.0);
uniform float field_extent=144.0;
uniform vec3 shallow_color:source_color=vec3(0.16,0.67,0.66);
uniform vec3 deep_color:source_color=vec3(0.035,0.30,0.40);
uniform float clarity=0.32;
uniform float refraction_factor=0.0025;
uniform float clock=0.0;
uniform float water_height=1.15;
uniform bool terrain_clipping=false;
uniform float foam_strength:hint_range(0.0,2.0)=1.0;
varying vec3 world_pos;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float soft_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
// Two alternating advection phases keep fine bubbles moving without stretching forever.
float foam_noise(vec2 p,vec2 velocity){
    float phase=fract(clock*0.22);
    float other=fract(clock*0.22+0.5);
    float blend=abs(phase*2.0-1.0);
    vec2 a=p-velocity*phase/0.22;
    vec2 b=p-velocity*other/0.22;
    return mix(soft_noise(a*4.2)*0.65+soft_noise(a*15.0)*0.35,
        soft_noise(b*4.2)*0.65+soft_noise(b*15.0)*0.35,blend);
}
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    vec2 fuv=(world_pos.xz-field_origin)/field_extent;
    VERTEX.y+=texture(wave_field,fuv).r;
    world_pos.y+=texture(wave_field,fuv).r;
}
void fragment(){
    vec2 fuv=(world_pos.xz-field_origin)/field_extent;
    vec4 field=texture(wave_field,fuv);
    vec2 px=vec2(1.0/field_resolution,0.0);
    vec4 fluid=texture(flow_field,fuv);
    vec2 flow=fluid.rg;
    vec2 slope=vec2(texture(wave_field,fuv+px.xy).r-texture(wave_field,fuv-px.xy).r,texture(wave_field,fuv+px.yx).r-texture(wave_field,fuv-px.yx).r);
    vec2 uv=world_pos.xz*0.18-flow*0.012;
    vec3 n1=texture(water_normal,uv+vec2(clock*0.018,clock*0.009)).rgb*2.0-1.0;
    vec3 n2=texture(water_normal,uv*0.63+vec2(-clock*0.012,clock*0.017)).rgb*2.0-1.0;
    vec2 gradient=slope/(2.0*field_extent/field_resolution);
    vec2 wave=n1.xy*0.16+n2.xy*0.11-gradient*2.2;
    float depth=texture(depth_tex,SCREEN_UV).r;
    vec4 p=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,depth*2.0-1.0,1.0);
    float thickness=max(0.0,-p.z/p.w+VERTEX.z);
    vec2 refracted=clamp(SCREEN_UV+wave*refraction_factor*min(thickness,1.2),vec2(0.002),vec2(0.998));
    float rd=texture(depth_tex,refracted).r;
    vec4 rp=INV_PROJECTION_MATRIX*vec4(refracted*2.0-1.0,rd*2.0-1.0,1.0);
    if(-rp.z/rp.w<-VERTEX.z+0.02)refracted=SCREEN_UV;
    vec3 ground=texture(screen_tex,refracted).rgb;
    vec4 ground_world=INV_VIEW_MATRIX*p/p.w;
    vec2 cuv=ground_world.xz*0.20+wave*0.10;
    float c1=texture(caustics_tex,cuv+vec2(clock*0.009,-clock*0.006)).r;
    float c2=texture(caustics_tex,cuv*1.13+vec2(-clock*0.006,clock*0.005)).r;
    float caustic=(max(c1,c2)*0.5+sqrt(c1*c2)*0.5)*exp(-thickness*0.19)*smoothstep(0.03,0.35,thickness);
    ground+=vec3(0.27,0.57,0.51)*caustic*0.24;
    float absorption=1.0-exp(-thickness*clarity);
    vec3 tint=mix(shallow_color,deep_color,1.0-exp(-thickness*0.22));
    vec3 color=mix(ground,tint,clamp(absorption*0.72+0.18,0.0,0.92));
    vec3 norm=normalize(vec3(wave.x*1.2,1.0,wave.y*1.2));
    vec3 light=normalize(vec3(0.35,0.85,-0.32));
    vec3 view_dir=normalize(CAMERA_POSITION_WORLD-world_pos);
    float spec=pow(max(dot(norm,normalize(light+view_dir)),0.0),48.0);
    color+=vec3(0.75,0.82,0.74)*spec*0.12;
    // Broad shading reads the same height map as displacement, above the fine normal detail.
    float facing=dot(normalize(vec3(-gradient.x*2.0,1.0,-gradient.y*2.0)),light);
    color*=0.88+facing*0.17;
    color+=shallow_color*smoothstep(0.02,0.22,field.r)*0.055;
    float wet_depth=water_height+field.r-field.g;
    if(terrain_clipping && wet_depth<0.006)discard;
    float bubbles=foam_noise(world_pos.xz,flow*0.65+vec2(0.018,-0.025));
    float steepness=length(gradient);
    float crest=smoothstep(0.08,0.22,steepness)*smoothstep(0.06,0.26,field.r);
    // World-space depth keeps the wet fringe consistent when the camera changes angle.

    float surge=clamp(fluid.a*0.65+length(flow)*0.16+max(field.r,0.0)*0.65,0.0,1.0);
    float shore=terrain_clipping ? 1.0-smoothstep(0.015,0.14,wet_depth) : 0.0;
    // A narrow broken lip stays readable. Persistent foam must not paint a broad white apron.
    float lip_noise=soft_noise(world_pos.xz*2.2-flow*0.25+vec2(clock*0.11,-clock*0.07));
    float lip=shore*0.65*smoothstep(0.28,0.52,lip_noise)*(0.42+surge*0.44);

    float density=clamp(field.b*1.10+crest*0.24+shore*surge*0.4,0.0,1.0);
    // Unbounded derivatives at the far camera made sparse bubbles become a milky sheet.
    float aa=clamp(fwidth(bubbles),0.015,0.05);
    float patches=smoothstep(0.74-density*0.35-aa,0.74-density*0.35+aa,bubbles);
    float residual=patches*smoothstep(0.05,0.24,density)*0.82;
    float white=clamp(max(lip,residual)*foam_strength,0.0,0.86);
    color=mix(color,vec3(0.91,0.97,0.91),white);
    ALBEDO=color;
    ALPHA=1.0;
}
