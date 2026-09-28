extends Node3D

const CITY_SCALE := 0.2
const START := Vector3(0,0.8,-24)
var city: Node3D
var player: CharacterBody3D
var visual: Node3D
var camera: Camera3D
var water: MeshInstance3D
var water_mat: ShaderMaterial
var retro_mat: ShaderMaterial
var status: Label
var feed_label: Label
var notice: Label
var help: PanelContainer
var pause_label: Label
var boost_bar: ProgressBar
var targets: Array[Node3D]=[]
var destructibles: Array[MeshInstance3D]=[]
var solids: Dictionary={}
var water_level:=1.15
var eaten:=0
var wrecked:=0
var growth:=1.0
var boost_time:=0.0
var cooldown:=0.0
var bite_timer:=0.0
var elapsed:=0.0
var camera_target:=START
var zoom:=108.0
var paused:=false
var clear_water:=false
var retro:=true
var shake:=0.0
var rng:=RandomNumberGenerator.new()
var ready_done:=false
var auto_capture:=false
var smoke_test:=false
var test_phase:=0
var test_origin:=Vector3.ZERO
var trace: Dictionary={}
var wave_sim:RefCounted
var fx:Node3D
var buildings:Dictionary={}
var node_building:Dictionary={}
var obstacle_boxes:Array=[]
var wake_timer:=0.0
var obstacle_timer:=0.0
var obstacle_dirty:=true
var last_obstacle_level:=-10.0
var combo:=0
var combo_timer:=0.0
var score:=0
var combo_label:Label
var bite_window:=0.0
var showcase:=false
var physics_frames:=0
var draw_frames:=0

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	rng.seed=4217
	auto_capture=OS.get_cmdline_user_args().has("--capture")
	smoke_test=OS.get_cmdline_user_args().has("--smoke-test")
	showcase=OS.get_cmdline_user_args().has("--showcase")
	_input_setup()
	_environment()
	_load_city()
	_make_water()
	if OS.get_cmdline_user_args().has("--dry"):water.visible=false
	_make_player()
	fx=Node3D.new();fx.set_script(load("res://scripts/impact_fx.gd"));fx.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(fx);fx.setup(self)
	_make_targets()
	_make_hud()
	ready_done=true
	print("READY: ",city.get_child_count()," imported scene nodes, ",solids.size()," colliders, ",targets.size()," targets")
	if auto_capture or smoke_test:
		_run_verification.call_deferred()
	if showcase:_run_showcase.call_deferred()

func _input_setup()->void:
	var keys={"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"boost":[KEY_SPACE],"bite":[KEY_E]}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action,0.2)
		InputMap.action_erase_events(action)
		for key in keys[action]:
			var ev:=InputEventKey.new();ev.physical_keycode=key;InputMap.action_add_event(action,ev)
	for spec in [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["forward",JOY_AXIS_LEFT_Y,-1.0],["back",JOY_AXIS_LEFT_Y,1.0]]:
		var ev:=InputEventJoypadMotion.new();ev.axis=spec[1];ev.axis_value=spec[2];InputMap.action_add_event(spec[0],ev)
	var boost_btn:=InputEventJoypadButton.new();boost_btn.button_index=JOY_BUTTON_B;InputMap.action_add_event("boost",boost_btn)
	var bite_btn:=InputEventJoypadButton.new();bite_btn.button_index=JOY_BUTTON_A;InputMap.action_add_event("bite",bite_btn)
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;InputMap.action_add_event("bite",mouse)

func _environment()->void:
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.22,0.24,0.22)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.68,0.71,0.65)
	env.ambient_light_energy=0.3
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var we:=WorldEnvironment.new();we.environment=env;add_child(we)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color(1.0,0.89,0.72)
	sun.light_energy=0.6
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=180
	add_child(sun)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(180,180);ground.mesh=plane
	ground.position=Vector3(0,-0.3,-20)
	var gm:=StandardMaterial3D.new();gm.albedo_color=Color(0.19,0.19,0.16);gm.roughness=1;ground.material_override=gm;add_child(ground)

func _load_city()->void:
	city=load("res://assets/extracted/rolla_city.gltf").instantiate()
	city.scale=Vector3.ONE*CITY_SCALE
	add_child(city)
	var meta: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_metadata.json"))
	var by_name:Dictionary={}
	for entry in meta:by_name[entry.node]=entry
	for node in city.get_children():
		if not node is MeshInstance3D:continue
		var mesh_node:=node as MeshInstance3D
		for i in mesh_node.mesh.get_surface_count():
			var m=mesh_node.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var item:Dictionary=by_name.get(node.name,{})
		var mesh_name:String=item.get("mesh","").to_lower()
		var source_path:String=item.get("path","")
		_register_building(mesh_node,source_path,mesh_name)
		mesh_node.set_meta("source_mesh",mesh_name)
		if mesh_name=="road":
			var asphalt:=StandardMaterial3D.new();asphalt.albedo_color=Color(0.18,0.20,0.19);asphalt.roughness=1.0;asphalt.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh_node.material_override=asphalt
		var breakable:=node_building.has(mesh_node.get_instance_id()) or mesh_name.contains("wall") or mesh_name.begins_with("car_") or mesh_name.contains("kyltti") or mesh_name.contains("tolppa") or mesh_name.contains("seina") or mesh_name.contains("house")
		if breakable:
			destructibles.append(mesh_node)
			mesh_node.set_meta("car",mesh_name.begins_with("car_"))
			mesh_node.set_meta("broken",false)
		if item.get("collider",false) and not mesh_name.contains("shadow") and not mesh_name.contains("grass"):
			var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
			mesh_node.add_child(body)
			var shape:=CollisionShape3D.new();shape.shape=mesh_node.mesh.create_trimesh_shape();body.add_child(shape)
			body.set_meta("visual",mesh_node)
			solids[mesh_node.get_instance_id()]=body
	# Navigation stays within the extracted area.
	for spec in [[Vector3(-61,3,-20),Vector3(1,16,150)],[Vector3(61,3,-20),Vector3(1,16,150)],[Vector3(0,3,-77),Vector3(125,16,1)],[Vector3(0,3,44),Vector3(125,16,1)]]:
		var b:=StaticBody3D.new();add_child(b);b.position=spec[0]
		var s:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=spec[1];s.shape=box;b.add_child(s)

func _make_water()->void:
	wave_sim=load("res://scripts/water_async.gd").new()
	water=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=Vector2(180,180);plane.subdivide_width=300;plane.subdivide_depth=300
	water.mesh=plane;water.position=Vector3(0,water_level,-20)
	water_mat=ShaderMaterial.new();water_mat.shader=load("res://shaders/water_v3.gdshader")
	water_mat.set_shader_parameter("water_normal",load("res://assets/extracted/sandcastle_water_normal.png"))
	water_mat.set_shader_parameter("caustics_tex",load("res://assets/effects/caustics.png"))
	water_mat.set_shader_parameter("wave_field",wave_sim.texture)
	water_mat.set_shader_parameter("flow_field",wave_sim.flow_texture)
	wave_sim.seed_swell()
	clear_water=false;_toggle_water()
	water.material_override=water_mat;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)

func _make_player()->void:
	player=CharacterBody3D.new();player.name="Shark";player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	player.collision_layer=2;player.collision_mask=1;add_child(player);player.position=START
	var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.55;shape.shape=sphere;player.add_child(shape)
	visual=Node3D.new();visual.set_script(load("res://scripts/shark.gd"));player.add_child(visual)
	camera=Camera3D.new();camera.fov=17;camera.near=0.1;camera.far=500;add_child(camera);camera.current=true
	_camera_update(1.0)

func _make_targets()->void:
	# Extracted civilian meshes with procedural swimming and capture motion.
	for i in 55:
		var target:Node3D=fx.make_civilian(i);add_child(target)
		var x:=rng.randf_range(-4.2,4.2)
		var z:float=-24.0-float(i%10)*3.0
		if i>=30:x=rng.randf_range(-25,25);z=-3.2+rng.randf_range(-3.0,3.0)
		target.position=Vector3(x,water_level,z)
		target.set_meta("phase",rng.randf()*TAU);targets.append(target)

func _make_hud()->void:
	var fx:=CanvasLayer.new();fx.layer=2;add_child(fx)
	var rect:=ColorRect.new();rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	retro_mat=ShaderMaterial.new();retro_mat.shader=load("res://shaders/retro.gdshader");rect.material=retro_mat;fx.add_child(rect)
	if OS.get_cmdline_user_args().has("--clean"):rect.visible=false
	var ui:=CanvasLayer.new();ui.layer=3;add_child(ui)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(root)
	var theme:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Arial"]);theme.default_font=font;theme.default_font_size=16;root.theme=theme
	var top:=PanelContainer.new();top.position=Vector2(24,22);top.custom_minimum_size=Vector2(350,110);root.add_child(top);_panel_style(top)
	var v:=VBoxContainer.new();top.add_child(v)
	var title:=Label.new();title.text="PRIME TIME  /  洪城";title.add_theme_font_size_override("font_size",26);title.modulate=Color(0.95,0.80,0.37);v.add_child(title)
	status=Label.new();v.add_child(status)
	boost_bar=ProgressBar.new();boost_bar.custom_minimum_size.y=5;boost_bar.show_percentage=false;v.add_child(boost_bar)
	var hint:=Label.new();hint.text="WASD 移动  ·  空格撞击  ·  接触吞噬 / E 吸入";hint.add_theme_font_size_override("font_size",13);v.add_child(hint)
	var bottom:=PanelContainer.new();root.add_child(bottom);bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_top=-59;bottom.offset_left=24;bottom.offset_right=-24;bottom.offset_bottom=-18;_panel_style(bottom)
	feed_label=Label.new();feed_label.add_theme_font_size_override("font_size",15);bottom.add_child(feed_label)
	notice=Label.new();notice.position=Vector2(26,150);notice.modulate=Color(0.94,0.77,0.40);root.add_child(notice)
	notice.text="洪水已进入街区。捕食成长，冲刺撞开车辆。"
	help=PanelContainer.new();root.add_child(help);help.position=Vector2(24,210);_panel_style(help);help.visible=false
	var text:=Label.new();text.text="操作说明\n\nWASD / 方向键 / 左摇杆：移动\n空格 / 手柄 B：冲刺（1 秒，冷却 5 秒）\n接触：自动吞噬；E / 左键 / 手柄 A：主动吸入\nPageUp / PageDown：升降水位\nT：切换清澈 / 浑浊水体\nTab：切换像素效果\n鼠标滚轮：镜头远近\nR：重新开始    Esc：暂停\nF11：全屏    F1：收起说明\n\n冲刺撞击车辆和建筑，破坏支撑可触发分段坍塌。";help.add_child(text)
	var corner:=Label.new();root.add_child(corner);corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);corner.offset_left=-330;corner.offset_top=26;corner.offset_right=-24;corner.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;corner.text="水体交互版本  03\nF1 操作说明  ·  F2 水体试验场"
	combo_label=Label.new();root.add_child(combo_label);combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);combo_label.offset_left=-310;combo_label.offset_top=88;combo_label.offset_right=-24;combo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;combo_label.add_theme_font_size_override("font_size",26);combo_label.modulate=Color(0.98,0.8,0.3)
	pause_label=Label.new();root.add_child(pause_label);pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER);pause_label.offset_left=-100;pause_label.offset_top=-30;pause_label.add_theme_font_size_override("font_size",32);pause_label.text="已暂停  /  ESC";pause_label.visible=false

func _panel_style(panel:PanelContainer)->void:
	var s:=StyleBoxFlat.new();s.bg_color=Color(0.045,0.065,0.07,0.9);s.border_color=Color(0.44,0.44,0.32);s.border_width_top=1;s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=8;s.content_margin_bottom=8;panel.add_theme_stylebox_override("panel",s)

func _unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("boost") and not paused:_start_boost()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:paused=not paused;pause_label.visible=paused;get_tree().paused=paused
			KEY_F1:help.visible=not help.visible
			KEY_F2:get_tree().paused=false;get_tree().change_scene_to_file("res://scenes/water_lab.tscn")
			KEY_R:get_tree().paused=false;get_tree().reload_current_scene()
			KEY_TAB:
				retro=not retro;retro_mat.set_shader_parameter("pixel_size",2.0 if retro else 1.0);retro_mat.set_shader_parameter("dither_strength",0.018 if retro else 0.0)
			KEY_T:_toggle_water()
			KEY_F11:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=clampf(zoom-12,80,240)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=clampf(zoom+12,80,240)

func _toggle_water()->void:
	clear_water=not clear_water
	water_mat.set_shader_parameter("shallow_color",Color(0.16,0.67,0.66) if clear_water else Color(0.17,0.40,0.36))
	water_mat.set_shader_parameter("deep_color",Color(0.035,0.30,0.40) if clear_water else Color(0.045,0.18,0.17))
	water_mat.set_shader_parameter("clarity",0.6 if clear_water else 0.65)

func _physics_process(dt:float)->void:
	if not ready_done or paused:return
	physics_frames+=1
	elapsed+=dt
	combo_timer=maxf(0,combo_timer-dt)
	if combo_timer<=0:combo=0
	bite_window=maxf(0,bite_window-dt)
	boost_time=maxf(0,boost_time-dt);cooldown=maxf(0,cooldown-dt);bite_timer=maxf(0,bite_timer-dt)
	if Input.is_physical_key_pressed(KEY_PAGEUP):water_level=minf(5.0,water_level+dt*0.55)
	if Input.is_physical_key_pressed(KEY_PAGEDOWN):water_level=maxf(0.25,water_level-dt*0.55)
	water.position.y=water_level
	var axis:=Input.get_vector("left","right","forward","back")
	var forward:Vector3=-camera.global_basis.z;forward.y=0;forward=forward.normalized()
	var right:Vector3=camera.global_basis.x;right.y=0;right=right.normalized()
	var dir:Vector3=right*axis.x-forward*axis.y
	var speed:float=lerpf(8.0,12.0,1.0/clampf(growth,1.0,9.0))*(1.5 if boost_time>0 else 1.0)
	player.velocity=player.velocity.move_toward(dir*speed,dt*45.0)
	player.velocity.y=0
	player.position.y=lerpf(player.position.y,water_level+wave_sim.sample_surface(player.position).y-0.12*growth,minf(1,dt*8))
	if dir.length()>0.1:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-dir.x,-dir.z),minf(1.0,dt*12.0))
	player.move_and_slide()
	if boost_time>0:
		_ram_nearby()
		for i in player.get_slide_collision_count():
			var hit:KinematicCollision3D=player.get_slide_collision(i)
			var body=hit.get_collider()
			if body and body.has_meta("visual"):
				var m:MeshInstance3D=body.get_meta("visual")
				if m in destructibles:_break_piece(m)
	if Input.is_action_pressed("bite") and bite_timer<=0:_bite()
	for i in range(targets.size()-1,-1,-1):
		var target:Node3D=targets[i]
		if not is_instance_valid(target):continue
		target.position.y=water_level+wave_sim.sample_surface(target.position).y+sin(elapsed*3+float(target.get_meta("phase")))*0.035
		var away:Vector3=target.position-player.position;away.y=0
		if away.length()<1.15*growth or (bite_window>0 and away.length()<3.0*growth):
			_capture_target(i);continue
		if away.length()<6 and away.length()>0.1:
			var wanted:Vector3=target.position+away.normalized()*dt*0.7
			var query:=PhysicsRayQueryParameters3D.create(target.position,wanted+away.normalized()*0.25,1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():target.position=wanted
			target.rotation.y=atan2(-away.x,-away.z)
		target.rotation.z=sin(elapsed*5+float(target.get_meta("phase")))*0.14
	_update_water(dt)
	fx.update(dt)
	_camera_update(dt)
	status.text="吞噬 %02d   /   体型 %.2f×   /   破坏 %02d"%[eaten,growth,wrecked]
	boost_bar.value=100.0*(1.0-clampf((cooldown-boost_time)/5.0,0,1))
	combo_label.text=("COMBO ×%d\n"%combo if combo>1 else "")+"%06d"%score
	feed_label.text="洪水现场   /   水位 %.1fm    ·    %s    |    PAGE↑↓ 调水位    |    %02d:%02d"%[water_level,"清澈水体" if clear_water else "末世浑水",int(elapsed)/60,int(elapsed)%60]

func _camera_update(dt:float)->void:
	camera_target=camera_target.lerp(player.position,1.0-exp(-dt/0.3))
	var dist:float=zoom+(growth-1.0)*22.0
	var offset:=Vector3(0.5,0.707106,-0.5)*dist
	shake=maxf(0,shake-dt*2.0)
	camera.position=camera_target+offset+Vector3(sin(elapsed*85),cos(elapsed*72),0)*shake*0.35
	camera.look_at(camera_target)

func _bite()->void:
	bite_timer=0.35;bite_window=0.22
	for i in range(targets.size()-1,-1,-1):
		var t:=targets[i]
		if is_instance_valid(t) and t.position.distance_to(player.position)<3.0*growth:_capture_target(i)
	fx.splash(player.position,0.65)

func _capture_target(i:int)->void:
	var target:Node3D=targets[i];targets.remove_at(i);fx.swallow(target)

func _finish_meal(pos:Vector3)->void:
	eaten+=1;growth=minf(3.2,1.0+eaten*0.065);combo+=1;combo_timer=3.0;score+=100*maxi(1,combo)
	(player.get_child(0) as CollisionShape3D).shape.radius=0.55*growth
	var tween:=create_tween();tween.tween_property(visual,"scale",Vector3.ONE*growth*1.08,0.08);tween.tween_property(visual,"scale",Vector3.ONE*growth,0.15)
	shake=0.22;fx.popup(pos,"+%d"%(100*maxi(1,combo)),Color(1,0.8,0.38))
	notice.text="吞噬 ×%d · 连击成长。冲刺可撞碎建筑。"%combo

func _start_boost()->void:
	if cooldown<=0:
		boost_time=1.0;cooldown=6.0;notice.text="冲刺！撞击车辆，或撕开墙片。"
		fx.splash(player.position,1.25);fx.sound("dash_mid",player.position,-17)

func _make_disaster_fx()->void:
	var positions:Array[Vector3]=[]
	for node in city.get_children():
		if node is MeshInstance3D and ("Roof" in node.name or "rooftile" in node.name):
			var pos:Vector3=node.global_position
			if pos.distance_to(START)>25 or pos.distance_to(START)<10:continue
			var good:=true
			for old in positions:
				if pos.distance_to(old)<10:good=false
			if good:
				var box:AABB=node.mesh.get_aabb();pos=node.global_transform*(box.position+box.size*Vector3(0.5,1.0,0.5));positions.append(pos)
			if positions.size()>=3:break
	for pos in positions:
		for fire in [false,true]:
			var p:=CPUParticles3D.new();p.amount=24 if fire else 34;p.lifetime=0.9 if fire else 5.5
			p.preprocess=4.0;p.local_coords=false;p.direction=Vector3.UP;p.spread=18
			p.gravity=Vector3(0.15,0.15,-0.08);p.initial_velocity_min=0.7;p.initial_velocity_max=1.4
			p.scale_amount_min=0.20 if fire else 0.5;p.scale_amount_max=0.6 if fire else 1.25
			p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=0.5
			var sphere:=SphereMesh.new();sphere.radius=0.5;sphere.height=1.0;sphere.radial_segments=6;sphere.rings=3
			var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1.0
			if fire:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			sphere.material=mat;p.mesh=sphere
			var gradient:=Gradient.new()
			gradient.colors=PackedColorArray([Color(1,0.7,0.13),Color(0.8,0.15,0.025),Color(0.18,0.09,0.045)]) if fire else PackedColorArray([Color(0.075,0.075,0.065),Color(0.14,0.15,0.14),Color(0.21,0.22,0.20)])
			gradient.offsets=PackedFloat32Array([0,0.5,1]);p.color_ramp=gradient
			var curve:=Curve.new();curve.add_point(Vector2(0,0.5));curve.add_point(Vector2(0.65,1.0));curve.add_point(Vector2(1,0.02));p.scale_amount_curve=curve
			add_child(p);p.position=pos

func _break_piece(m:MeshInstance3D)->void:
	if m.get_meta("broken",false):return
	m.set_meta("broken",true);wrecked+=1;shake=0.6
	if solids.has(m.get_instance_id()):
		var body:StaticBody3D=solids[m.get_instance_id()];body.collision_layer=0
	var impulse:Vector3=player.velocity
	if impulse.length()<0.5:impulse=-visual.global_basis.z*8
	if m.get_meta("car",false):fx.launch_car(m,impulse)
	else:
		fx.fracture(m,impulse,8)
		_damage_structure(m,impulse)
	obstacle_dirty=true;score+=250;combo+=1;combo_timer=3
	notice.text="撞毁车辆！" if m.get_meta("car",false) else "墙片破坏！"

func _run_verification()->void:
	await get_tree().create_timer(3.0).timeout
	if smoke_test:
		test_origin=player.position
		Input.action_press("forward")
		await get_tree().create_timer(0.5).timeout
		Input.action_release("forward")
		trace["movement_distance"]=player.position.distance_to(test_origin)
		var t:=targets[0];t.position=player.position+Vector3(0.7,0,0);_bite()
		await get_tree().create_timer(0.6).timeout
		trace["eaten_after_bite"]=eaten;trace["growth"]=growth
		var press:=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=true
		Input.parse_input_event(press);await get_tree().create_timer(0.08).timeout
		press=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=false;Input.parse_input_event(press)
		trace["boost_started"]=cooldown>0
		water_level=1.6;await get_tree().create_timer(0.1).timeout;trace["water_y"]=water.position.y
		var old_mode:=clear_water;_toggle_water();trace["water_mode_changed"]=clear_water!=old_mode
		trace["wall_collision"]=false
		for m in destructibles:
			if not solids.has(m.get_instance_id()):continue
			var bounds:AABB=m.global_transform*m.mesh.get_aabb()
			if bounds.size.y<1 or bounds.position.y>water_level or bounds.end.y<water_level:continue
			var axis:=Vector3.RIGHT if bounds.size.x<bounds.size.z else Vector3.BACK
			var center:=bounds.get_center();center.y=water_level
			var extent:float=(bounds.size.x if axis==Vector3.RIGHT else bounds.size.z)*0.5
			var from:=center-axis*(extent+2.0)
			if player.test_move(Transform3D(Basis.IDENTITY,from),axis*(extent*2.0+4.0)):
				trace["wall_collision"]=true;break
		if not destructibles.is_empty():_break_piece(destructibles[0]);trace["destruction_count"]=wrecked
		await get_tree().create_timer(0.7).timeout
		trace["wave_impulses"]=wave_sim.total_impulses;trace["wave_energy"]=wave_sim.energy();trace["swallow_animations"]=fx.swallow_count;trace["fragment_count"]=fx.spawned_fragments;trace["splash_count"]=fx.splash_count
		trace["passed"]=trace.movement_distance>1.0 and eaten>0 and growth>1.0 and trace.boost_started and absf(water.position.y-1.6)<0.01 and trace.water_mode_changed and trace.wall_collision and wrecked>0 and fx.swallow_count>0 and fx.spawned_fragments>0 and wave_sim.total_impulses>3
		trace["fps"]=Engine.get_frames_per_second()
		trace["wave_step_ms"]=wave_sim.last_step_ms
		FileAccess.open("res://research/smoke_test.json",FileAccess.WRITE).store_string(JSON.stringify(trace,"  "))
		print("SMOKE_TEST ",trace)
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	image.save_png("res://research/smoke_preview.png" if smoke_test else "res://research/prototype_preview.png")
	print("CAPTURE_SAVED")
	get_tree().quit(0 if not smoke_test or trace.get("passed",false) else 1)

func _register_building(m:MeshInstance3D,path:String,mesh_name:String)->void:
	if mesh_name.begins_with("car_") or mesh_name=="road":return
	var segments:=path.split("/",false)
	var group:=""
	for i in range(1,segments.size()-1):
		var s:String=segments[i].to_lower()
		if "lowrise" in s or "highriser" in s or "kioskitalo" in s or s.begins_with("store") or "house" in s:
			group="/".join(segments.slice(0,i+1));break
	if group.is_empty():return
	if not buildings.has(group):buildings[group]={"parts":[],"hits":0,"collapsing":false}
	buildings[group].parts.append(m);node_building[m.get_instance_id()]=group

func _damage_structure(m:MeshInstance3D,impulse:Vector3)->void:
	var key:String=node_building.get(m.get_instance_id(),"")
	if key.is_empty():return
	var b:Dictionary=buildings[key]
	if b.collapsing:return
	b.hits+=1
	var bounds:AABB=m.global_transform*m.mesh.get_aabb()
	if b.hits<2 and bounds.position.y>water_level+0.6:return
	b.collapsing=true
	var parts:Array=b.parts.duplicate()
	parts.sort_custom(func(a:MeshInstance3D,c:MeshInstance3D):return (a.global_transform*a.mesh.get_aabb()).get_center().y<(c.global_transform*c.mesh.get_aabb()).get_center().y)
	var delay:=0.05
	for node:MeshInstance3D in parts:
		if node==m or not node.visible:continue
		delay+=0.035
		get_tree().create_timer(delay).timeout.connect(_collapse_part.bind(node,impulse))
	notice.text="建筑失去支撑 · 连锁坍塌！"

func _ram_nearby()->void:
	var sphere:=SphereShape3D.new();sphere.radius=0.85*growth
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.collision_mask=1
	var heading:Vector3=player.velocity.normalized() if player.velocity.length()>0.1 else -visual.global_basis.z
	query.transform=Transform3D(Basis.IDENTITY,player.position+heading*0.65*growth)
	var hits:Array=get_world_3d().direct_space_state.intersect_shape(query,12)
	var count:=0
	for hit in hits:
		var b:Node=hit.collider
		if b.has_meta("visual"):
			var m:MeshInstance3D=b.get_meta("visual")
			if m in destructibles and not m.get_meta("broken",false):
				_break_piece(m);count+=1
				if count>=2:break

func _collapse_part(node:MeshInstance3D,impulse:Vector3)->void:
	if not is_instance_valid(node) or node.get_meta("broken",false):return
	if paused:
		get_tree().create_timer(0.2).timeout.connect(_collapse_part.bind(node,impulse));return
	node.set_meta("broken",true)
	if solids.has(node.get_instance_id()):solids[node.get_instance_id()].collision_layer=0
	fx.fracture(node,impulse,3);wrecked+=1;score+=75;obstacle_dirty=true;shake=maxf(shake,0.25)

func _update_water(dt:float)->void:
	wake_timer+=dt;obstacle_timer+=dt
	if obstacle_timer>0.35 and (obstacle_dirty or absf(water_level-last_obstacle_level)>0.2):
		obstacle_timer=0;obstacle_dirty=false;last_obstacle_level=water_level;obstacle_boxes.clear()
		for m in destructibles:
			if not m.visible or m.get_meta("broken",false):continue
			var box:AABB=m.global_transform*m.mesh.get_aabb()
			if box.size.y>0.5:obstacle_boxes.append(box)
		wave_sim.set_obstacles(obstacle_boxes,water_level)
	if wake_timer>0.06:
		wave_sim.swimmer(player.position,player.velocity,growth,wake_timer)
		for target in targets:
			if not is_instance_valid(target):continue
			var last:Vector3=target.get_meta("water_previous",target.position)
			var swim_velocity:Vector3=(target.position-last)/wake_timer;swim_velocity.y=0
			if target.position.distance_squared_to(player.position)<400:
				wave_sim.swimmer(target.position,swim_velocity,0.35,wake_timer)
			target.set_meta("water_previous",target.position)
		wake_timer=0
	wave_sim.update(dt)
	water_mat.set_shader_parameter("clock",elapsed)
	water_mat.set_shader_parameter("water_height",water_level)

func _run_showcase()->void:
	# Deterministic in-engine capture with actual inputs. No offline video effects.
	await get_tree().create_timer(1.0).timeout
	for i in mini(8,targets.size()):
		targets[i].position=player.position+Vector3(float(i%3-1)*0.8,0,float(i/3)*1.0)
	_bite()
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://research/v2_swallow.png")
	Input.action_press("back")
	await get_tree().create_timer(1.0).timeout
	_start_boost()
	await get_tree().create_timer(1.0).timeout
	Input.action_release("back")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://research/v2_wake.png")
	var selected:MeshInstance3D
	var best:=1000.0
	for m in destructibles:
		if m.get_meta("car",false) or not node_building.has(m.get_instance_id()):continue
		var box:AABB=m.global_transform*m.mesh.get_aabb()
		var distance:float=box.get_center().distance_to(player.position)
		if box.position.y<water_level and box.end.y>water_level and distance<best:selected=m;best=distance
	if selected:
		var box:AABB=selected.global_transform*selected.mesh.get_aabb()
		var center:=box.get_center();center.y=water_level
		var dir:Vector3=(center-player.position).normalized();dir.y=0;dir=dir.normalized()
		# Move toward the selected facade; boost collision uses the same gameplay path.
		var from:Vector3=center-dir*(maxf(box.size.x,box.size.z)*0.5+3.0)
		player.position=from
		camera_target=from
		cooldown=0;_start_boost()
		var forward:Vector3=-camera.global_basis.z;forward.y=0;forward=forward.normalized()
		var right:Vector3=camera.global_basis.x;right.y=0;right=right.normalized()
		var ax:float=dir.dot(right);var ay:float=dir.dot(forward)
		Input.action_press("right" if ax>0 else "left",absf(ax));Input.action_press("forward" if ay>0 else "back",absf(ay))
		await get_tree().create_timer(1.0).timeout
		for action in ["right","left","forward","back"]:Input.action_release(action)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://research/v2_action.png")
	await get_tree().create_timer(2.5).timeout
	print("SHOWCASE_END fragments=",fx.spawned_fragments," swallowed=",fx.swallow_count," waves=",wave_sim.total_impulses)
	var checks:Dictionary={"collision_driven_broken_parts":wrecked,"physics_fragments_spawned":fx.spawned_fragments,"swallow_animations":fx.swallow_count,"water_impulses":wave_sim.total_impulses,"active_fragments":fx.fragments.size(),"wave_step_ms":wave_sim.last_step_ms,"fps":Engine.get_frames_per_second()}
	checks["passed"]=wrecked>5 and fx.spawned_fragments>15 and fx.swallow_count>=8 and wave_sim.total_impulses>50 and fx.fragments.size()<=110
	FileAccess.open("res://research/v2_validation.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	get_tree().quit(0 if checks.passed else 1)

func _exit_tree()->void:
	if wave_sim:wave_sim.shutdown()
