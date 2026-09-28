shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D wave_field:filter_linear,repeat_disable;
uniform vec2 field_origin=vec2(-72.0,-88.0);
uniform float field_extent=144.0;
uniform float water_y=1.15;
uniform bool terrain_clipping=false;
varying vec3 world_pos;
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float h=texture(wave_field,(world_pos.xz-field_origin)/field_extent).r;
    // Instances are horizontal and live in world space; all share the simulated surface.
    VERTEX.y+=water_y+h+0.035;
    world_pos.y=water_y+h+0.035;
}
void fragment(){
    // Opaque scene depth clips the real shore/rock. Coarse obstacle floor cells
    // would wrongly erase precisely the particles that hug the waterline.
    // Reconstructed from Lit/Whitewater PS: radial disk, soft alpha, no ring texture.
    float radius=length(UV-vec2(0.5));
    if(radius>0.5)discard;
    ALBEDO=vec3(0.95,0.97,0.94);
    ALPHA=max(0.5-radius,0.0)*COLOR.a;
}
