extends Node3D
var sim:RefCounted
var mat:ShaderMaterial
var player:CharacterBody3D
var shark:Node3D
var camera:Camera3D
var objects:Array[Node3D]=[]
var time:=0.0
var wake:=0.0
var label:Label
var demo:=false
var captured:=false
var max_bob:=0.0
var boost:=0.0
var water_fx:Node3D

func sand_y(x:float,z:float)->float:
	return 0.4-z*0.13+sin(x*0.25)*0.24+sin(z*0.6+x*0.2)*0.08

func material(color:Color)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.88;m.cull_mode=BaseMaterial3D.CULL_DISABLED;return m

func _ready()->void:
	demo=OS.get_cmdline_user_args().has("--water-demo")
	sim=load("res://scripts/water_async.gd").new();sim.configure(48,Vector2(-24,-24),1.0)
	sim.deterministic=demo
	sim.swell_amplitude=0.28
	water_fx=Node3D.new();water_fx.set_script(load("res://scripts/wake_fx.gd"));add_child(water_fx);water_fx.setup(sim,1.0)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("929c98");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("ced9d6");env.ambient_light_energy=0.35
	var we:=WorldEnvironment.new();we.environment=env;add_child(we)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);sun.light_color=Color("fff2d2");sun.light_energy=0.65;sun.shadow_enabled=true;add_child(sun)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-24,24):
		for x in range(-24,24):
			for v in [Vector2(x,z),Vector2(x+1,z+1),Vector2(x+1,z),Vector2(x,z),Vector2(x,z+1),Vector2(x+1,z+1)]:
				st.set_color(Color(0.62,0.56,0.40)*(0.96+sin(v.x*3.8+v.y*6.1)*0.025));st.add_vertex(Vector3(v.x,sand_y(v.x,v.y),v.y))
	st.generate_normals();var ground:=MeshInstance3D.new();ground.mesh=st.commit();var sand:=material(Color.WHITE);sand.vertex_color_use_as_albedo=true;ground.material_override=sand;add_child(ground)
	for z in sim.N:
		for x in sim.N:sim.base_floor[z*sim.N+x]=sand_y(-24+x*sim.cell,-24+z*sim.cell)
	# Round footprints, unlike the conservative city AABB approximation.
	for spec in [[Vector3(-7,0,2),2.1],[Vector3(6,0,-2),2.7],[Vector3(8,0,11),1.5],[Vector3(-13,0,12),1.1]]:
		var p:Vector3=spec[0];var radius:float=spec[1];p.y=sand_y(p.x,p.z)+radius*0.60
		var rock:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*1.55;mesh.radial_segments=9;mesh.rings=5;rock.mesh=mesh;rock.position=p;rock.material_override=material(Color("6f7164"));add_child(rock)
		var b:=StaticBody3D.new();rock.add_child(b);var c:=CollisionShape3D.new();var s:=SphereShape3D.new();s.radius=radius;c.shape=s;b.add_child(c)
		for z in sim.N:
			for x in sim.N:
				var d:=Vector2(-24+x*sim.cell-p.x,-24+z*sim.cell-p.z).length()
				if d<radius:sim.base_floor[z*sim.N+x]=maxf(sim.base_floor[z*sim.N+x],p.y+sqrt(radius*radius-d*d)*0.77)
	var wall:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(6,3,0.65);wall.mesh=box;wall.position=Vector3(-2,0.8,-1);wall.material_override=material(Color("787e7c"));add_child(wall)
	var wb:=StaticBody3D.new();wall.add_child(wb);var wc:=CollisionShape3D.new();var ws:=BoxShape3D.new();ws.size=box.size;wc.shape=ws;wb.add_child(wc)
	sim.set_obstacles([AABB(wall.position-box.size*0.5,box.size)],1.0);sim.seed_swell()
	var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(48,48);plane.subdivide_width=240;plane.subdivide_depth=240;water.mesh=plane;water.position.y=1
	mat=ShaderMaterial.new();mat.shader=load("res://shaders/water_v3.gdshader")
	mat.set_shader_parameter("water_normal",load("res://assets/extracted/sandcastle_water_normal.png"));mat.set_shader_parameter("caustics_tex",load("res://assets/effects/caustics.png"));mat.set_shader_parameter("wave_field",sim.texture);mat.set_shader_parameter("flow_field",sim.flow_texture);mat.set_shader_parameter("field_extent",48.0);mat.set_shader_parameter("field_origin",Vector2(-24,-24));mat.set_shader_parameter("water_height",1.0);mat.set_shader_parameter("clarity",0.25)
	water.material_override=mat;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)
	mat.set_shader_parameter("terrain_clipping",true)
	player=CharacterBody3D.new();player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;player.position=Vector3(-2,1,15);add_child(player)
	var cs:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.55;cs.shape=sphere;player.add_child(cs)
	shark=Node3D.new();shark.set_script(load("res://scripts/shark.gd"));player.add_child(shark)
	for i in 6:
		var log_mesh:=MeshInstance3D.new();var lm:=BoxMesh.new();lm.size=Vector3(0.7,0.45,1.6);log_mesh.mesh=lm;log_mesh.material_override=material(Color("725438"));log_mesh.position=Vector3(-10+i*3.6,1,6+float(i%2)*8);add_child(log_mesh);objects.append(log_mesh)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=47;camera.position=Vector3(28,39,34);add_child(camera);camera.look_at(Vector3(0,0,1));camera.current=true
	var ui:=CanvasLayer.new();add_child(ui);label=Label.new();label.position=Vector2(24,18);label.add_theme_font_size_override("font_size",19);label.add_theme_color_override("font_color",Color("112c31"));ui.add_child(label)
	var hint:=Label.new();hint.text="WASD 游动   SPACE 冲刺   Q 发出海浪   F2 返回城市   R 重置\n浅水传播 · 障碍物反射 / 绕射 · 白沫随流漂移 · 漂浮物反馈";hint.position=Vector2(24,648);hint.add_theme_font_size_override("font_size",17);hint.add_theme_color_override("font_color",Color("112c31"));ui.add_child(hint)

func _unhandled_input(e:InputEvent)->void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_F2:get_tree().change_scene_to_file("res://scenes/main.tscn")
			KEY_R:get_tree().reload_current_scene()
			KEY_SPACE:boost=0.6
			KEY_Q:
				water_fx.audio.wave()
				for x in range(-20,21):sim.disturb(Vector3(x,1,19),1.5,0.32,0.18,Vector2(0,-0.45))

func _physics_process(dt:float)->void:
	time+=dt;wake+=dt;boost=maxf(0,boost-dt)
	var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var direction:Vector3=camera.global_basis.x*axis.x+camera.global_basis.z*axis.y;direction.y=0;direction=direction.normalized()
	if demo:
		direction=Vector3(0,0,-1) if time<2.0 else (Vector3(1,0,0.3).normalized() if time<4.5 else Vector3.ZERO)
		if time>3 and time<3.5:boost=0.2
	var field:Vector3=sim.sample_surface(player.position)
	player.velocity=player.velocity.move_toward(direction*(9 if boost>0 else 4.5)+Vector3(field.x,0,field.z)*0.25,dt*18);player.velocity.y=0
	player.position.y=lerpf(player.position.y,1+field.y-0.52,minf(1,dt*10));player.move_and_slide()
	player.position.x=clampf(player.position.x,-21,21);player.position.z=clampf(player.position.z,-2,21)
	water_fx.audio.follow(player.global_position,camera)
	water_fx.swimmer(0,player.position,player.velocity,1.0)
	shark.update_motion(dt,player.velocity.length(),false)
	if direction.length()>0.1:shark.rotation.y=lerp_angle(shark.rotation.y,atan2(-direction.x,-direction.z),minf(1,dt*8))
	if wake>0.065:
		sim.swimmer(player.position,player.velocity,1.0,wake)
		for obj in objects:
			var f:Vector3=sim.sample_surface(obj.position)
			var old:=obj.position;obj.position+=Vector3(f.x,0,f.z)*wake*0.65;obj.position.y=lerpf(obj.position.y,1+f.y+0.06,0.25)
			obj.rotation.x=lerpf(obj.rotation.x,(sim.sample_surface(obj.position+Vector3(0,0,0.7)).y-sim.sample_surface(obj.position-Vector3(0,0,0.7)).y)/1.4,0.2)
			if obj.position.distance_to(player.position)<1.7:
				var push:Vector3=(obj.position-player.position).normalized();obj.position+=push*wake*2
			var vel:Vector3=(obj.position-old)/wake
			sim.disturb(obj.position,0.5,clampf(-vel.y*0.015,-0.025,0.025),0.006,Vector2(vel.x,vel.z)*0.025)
			max_bob=maxf(max_bob,absf(obj.position.y-1.06))
		wake=0
	sim.update(dt);mat.set_shader_parameter("clock",time)
	label.text="WATER STUDY 12 / 水体试验场\n海浪与游动共用水高、流速和泡沫场"
	if demo and time>5.5 and not captured:
		captured=true;_capture("res://research/v3_water_action.png")
	if demo and time>11:
		set_physics_process(false);await _capture("res://research/v3_water_rest.png")
		var report:={"finite":is_finite(sim.energy()),"energy":sim.energy(),"max_height":sim.max_height,"floating_bob":max_bob,"impulses":sim.total_impulses,"step_ms":sim.last_step_ms}
		FileAccess.open("res://research/v3_water_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("WATER_DEMO ",report);get_tree().quit()

func _capture(path:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _exit_tree()->void:
	if sim:sim.shutdown()
