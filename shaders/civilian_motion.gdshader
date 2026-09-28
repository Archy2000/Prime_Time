shader_type spatial;
render_mode cull_disabled;
uniform sampler2D skin_texture : source_color, filter_nearest;
uniform vec4 skin_color : source_color = vec4(1.0);
uniform bool textured = false;
uniform vec3 bounds_min;
uniform float body_height = 1.0;
uniform float motion_phase = 0.0;
uniform float activity = 0.0;
uniform bool swimming = true;
uniform bool posed = false;

mat3 rx(float a) {
 float c=cos(a); float s=sin(a);
 return mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c));
}
mat3 rz(float a) {
 float c=cos(a); float s=sin(a);
 return mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1));
}
void vertex() {
 vec3 p=(VERTEX-bounds_min)/body_height;
 // bounds_min.x/z are the center of the original mesh, y is its foot height.
 float side=p.x<0.0 ? -1.0 : 1.0;
 float beat=motion_phase+(side<0.0 ? 3.14159265 : 0.0);
 mat3 turn=mat3(1.0);
 if (!posed && abs(p.x)>0.145 && p.y>0.60) {
  vec3 shoulder=vec3(side*0.145,0.77,0.0);
  vec3 elbow=vec3(side*0.32,0.77,0.0);
  float elbow_weight=smoothstep(0.29,0.36,abs(p.x));
  mat3 bend=rz(side*(swimming ? 0.48 : -0.20)*elbow_weight)*rx(-0.85*elbow_weight);
  p=elbow+bend*(p-elbow);
  turn=swimming ? rx(sin(beat)*0.85)*rz(side*(0.9+cos(beat)*0.6)) : rx(sin(beat)*activity*0.85)*rz(-side*1.32);
  p=shoulder+turn*(p-shoulder);
  NORMAL=turn*bend*NORMAL;
 } else if (p.y<0.48) {
  vec3 hip=vec3(side*0.075,0.48,0.0);
  vec3 knee=vec3(side*0.075,0.25,0.0);
  float knee_weight=1.0-smoothstep(0.20,0.29,p.y);
  mat3 bend=rx(max(0.0,-sin(beat))*(swimming ? 0.38 : 1.0)*activity*knee_weight);
  p=knee+bend*(p-knee);
  turn=rx(sin(beat)*(swimming ? 0.24 : 0.72)*activity);
  p=hip+turn*(p-hip);
  NORMAL=turn*bend*NORMAL;
 }
 VERTEX=p*body_height+bounds_min;
}
void fragment() {
 ALBEDO=skin_color.rgb;
 if (textured) { ALBEDO*=texture(skin_texture,UV).rgb; }
 ROUGHNESS=1.0;
}
