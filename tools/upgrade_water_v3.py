from pathlib import Path
p=Path('shaders/water_v2.gdshader');s=p.read_text()
s=s.replace('uniform vec2 field_origin', 'uniform sampler2D flow_field:filter_linear,repeat_disable;\nuniform float field_resolution=160.0;\nuniform vec2 field_origin')
s=s.replace('VERTEX.y+=texture(wave_field,fuv).r*0.28+tide(world_pos.xz);','VERTEX.y+=texture(wave_field,fuv).r;\n    world_pos.y+=texture(wave_field,fuv).r;')
s=s.replace('vec2 px=vec2(1.0/192.0,0.0);','vec2 px=vec2(1.0/field_resolution,0.0);\n    vec2 flow=texture(flow_field,fuv).rg;')
s=s.replace('vec2 uv=world_pos.xz*0.12;', 'vec2 uv=world_pos.xz*0.18-flow*0.012;')
s=s.replace('slope*2.5','slope/(2.0*field_extent/field_resolution)*3.0')
a=s.index('    float shoreline=');b=s.index('    color=mix',a)
s=s[:a]+'''    float wet_depth=water_height+field.r-field.g;
    if(field.a>0.65 || wet_depth<0.006)discard;
    float edge=(1.0-smoothstep(0.015,0.20,thickness));
    float lace=smoothstep(0.08,0.48,noise+n1.x*0.15);
    float micro=texture(caustics_tex,world_pos.xz*2.7-flow*clock*0.015).r;
    float turbulence=field.b*smoothstep(0.04,0.25,noise+micro*0.35);
    float steepness=length(slope)/(2.0*field_extent/field_resolution);
    float crest=smoothstep(0.065,0.18,steepness)*smoothstep(0.035,0.13,field.r);
    float white=clamp(edge*lace*0.55+turbulence*1.1+crest*lace*0.60,0.0,0.93);
''' + s[b:]
Path('shaders/water_v3.gdshader').write_text(s)
p=Path('scripts/main.gd');s=p.read_text(encoding='utf-8-sig')
s=s.replace('scripts/water_sim.gd','scripts/water_hydro.gd').replace('shaders/water_v2.gdshader','shaders/water_v3.gdshader')
s=s.replace('plane.subdivide_width=180;plane.subdivide_depth=180','plane.subdivide_width=300;plane.subdivide_depth=300')
s=s.replace('water_mat.set_shader_parameter("wave_field",wave_sim.texture)','water_mat.set_shader_parameter("wave_field",wave_sim.texture)\n\twater_mat.set_shader_parameter("flow_field",wave_sim.flow_texture)\n\twave_sim.seed_swell()')
s=s.replace('KEY_F1:help.visible=not help.visible','KEY_F1:help.visible=not help.visible\n\t\t\tKEY_F2:get_tree().paused=false;get_tree().change_scene_to_file("res://scenes/water_lab.tscn")')
s=s.replace('player.position.y=water_level-0.12*growth','player.position.y=lerpf(player.position.y,water_level+wave_sim.sample_surface(player.position).y-0.12*growth,minf(1,dt*8))')
s=s.replace('target.position.y=water_level+sin', 'target.position.y=water_level+wave_sim.sample_surface(target.position).y+sin')
s=s.replace('交互效果版本  02','水体交互版本  03').replace('F1 操作说明  ·  T 水体对比','F1 操作说明  ·  F2 水体试验场')
s=s.replace('if not m.visible or m.get_meta("broken",false) or m.get_meta("car",false):continue','if not m.visible or m.get_meta("broken",false):continue')
a=s.index('\tif wake_timer>0.10');b=s.index('\twave_sim.update(dt)',a)
s=s[:a]+'''\tif wake_timer>0.06:
\t\twave_sim.swimmer(player.position,player.velocity,growth,wake_timer)
\t\twake_timer=0
''' + s[b:]
p.write_text(s,encoding='utf8')
