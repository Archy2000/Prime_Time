shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size = 2.0;
uniform float contrast = 1.32;
uniform float exposure = 0.94;
uniform float saturation = 0.84;
uniform float grade_strength = 0.65;
uniform float color_levels = 32.0;
uniform float dither_strength = 0.55;
uniform float scanline_strength = 0.12;
uniform float chromatic_strength = 0.35;
uniform float bloom_strength = 0.12;
uniform float grain_strength = 0.008;
uniform float vignette_strength = 0.18;
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 bright(vec2 uv) {
    vec3 c = texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
    return c * smoothstep(0.65, 1.0, luma(c));
}
float bayer4(vec2 p) {
    vec2 a = mod(p, 2.0);
    vec2 b = mod(floor(p / 2.0), 2.0);
    float lo = 2.0*a.x + 3.0*a.y - 4.0*a.x*a.y;
    float hi = 2.0*b.x + 3.0*b.y - 4.0*b.x*b.y;
    return (4.0*lo + hi + 0.5)/16.0 - 0.5;
}
void fragment() {
    vec2 size = vec2(textureSize(screen_tex, 0));
    // 360 virtual rows at the default setting, independent of window resolution.
    float block = max(1.0, pixel_size * size.y / 720.0);
    vec2 grid = floor(size / block);
    vec2 p = floor(SCREEN_UV * grid);
    vec2 uv = (p + 0.5) / grid;
    vec2 texel = 1.0 / grid;
    vec3 c = texture(screen_tex, uv).rgb;
    if (chromatic_strength > 0.0) {
        vec2 offset = vec2(texel.x, 0.0);
        c.r = mix(c.r, texture(screen_tex, clamp(uv+offset, vec2(0.0), vec2(1.0))).r, chromatic_strength*0.35);
        c.b = mix(c.b, texture(screen_tex, clamp(uv-offset, vec2(0.0), vec2(1.0))).b, chromatic_strength*0.35);
    }
    if (bloom_strength > 0.0) {
        vec3 halo = bright(uv+texel*vec2(2.0,0.0)) + bright(uv-texel*vec2(2.0,0.0));
        halo += bright(uv+texel*vec2(0.0,2.0)) + bright(uv-texel*vec2(0.0,2.0));
        c += halo*bloom_strength*0.25;
    }
    c = (c*exposure - 0.5)*contrast + 0.5;
    float y = luma(c);
    c = mix(vec3(y), c, saturation);
    float shadows = 1.0-smoothstep(0.05,0.65,y);
    float highlights = smoothstep(0.55,1.0,y);
    c += grade_strength*(vec3(-0.055,0.014,0.021)*shadows + vec3(0.035,0.022,-0.025)*highlights);
    float grain = fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453)-0.5;
    c += grain*grain_strength;
    c = floor(clamp(c+bayer4(p)*dither_strength/color_levels,0.0,1.0)*color_levels+0.5)/color_levels;
    float line = 0.5+0.5*sin(SCREEN_UV.y*grid.y*6.2831853);
    c *= 1.0-scanline_strength*line*smoothstep(1.0,2.0,block);
    vec2 centered = (SCREEN_UV-0.5)*2.0;
    c *= 1.0-vignette_strength*smoothstep(0.15,1.65,dot(centered,centered));
    COLOR = vec4(clamp(c,0.0,1.0),1.0);
}

