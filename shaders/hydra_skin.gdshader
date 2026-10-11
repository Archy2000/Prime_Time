shader_type spatial;
render_mode cull_disabled;
uniform float motion_phase = 0.0;
uniform float jaw_open = 0.0;
uniform bool undead = false;
varying vec3 skin_position;
varying float skin_mask;

float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
	vec3 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex() {
	vec3 p = VERTEX;
	skin_position = p;
	skin_mask = UV2.x;
	// Continuous deformation: branch roots stay anchored in the shared torso.
	float branch = UV.x;
	float weight = UV.y;
	p.x += sin(motion_phase * 1.6 + branch * 0.91) * 0.025 * weight;
	p.y += sin(motion_phase * 1.9 + branch * 0.67) * 0.012 * weight;
	float tail = smoothstep(0.65, 2.45, VERTEX.z);
	p.x += sin(motion_phase * 3.0 - VERTEX.z * 3.0) * 0.16 * tail;
	p.y -= jaw_open * UV2.y * 0.12;
	VERTEX = p;
}

void fragment() {
	float grain = noise3(skin_position*35.0)-0.5;
	float mottling = noise3(skin_position*7.0)-0.5;
	vec3 skin = COLOR.rgb * (1.0 + (grain * 0.04 + mottling * 0.12) * skin_mask);
	if (undead) skin = mix(skin, skin * vec3(0.72, 1.13, 0.60), skin_mask * 0.8);
	ALBEDO = skin;
	EMISSION = skin * 0.10 * skin_mask;
	ROUGHNESS = mix(0.25, 0.53, skin_mask);
	SPECULAR = 0.32;
}
