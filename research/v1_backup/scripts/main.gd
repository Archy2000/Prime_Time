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

func _ready()->void:
	rng.seed=4217
	auto_capture=OS.get_cmdline_user_args().has("--capture")
	smoke_test=OS.get_cmdline_user_args().has("--smoke-test")
	_input_setup()
	_environment()
	_load_city()
	_make_water()
	if OS.get_cmdline_user_args().has("--dry"):water.visible=false
	_make_player()
	_make_targets()
	_make_disaster_fx()
	_make_hud()
	ready_done=true
	print("READY: ",city.get_child_count()," imported scene nodes, ",solids.size()," colliders, ",targets.size()," targets")
	if auto_capture or smoke_test:
		_run_verification.call_deferred()

func _input_setup()->void:
	var keys={"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"boost":[KEY_SPACE],"bite":[KEY_E]}
	for action in keys:
		InputMap.add_action(action,0.2)
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
		if mesh_name=="road":
			var asphalt:=StandardMaterial3D.new();asphalt.albedo_color=Color(0.18,0.20,0.19);asphalt.roughness=1.0;asphalt.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh_node.material_override=asphalt
		var breakable:=mesh_name.contains("wall") or mesh_name.begins_with("car_") or mesh_name.contains("kyltti") or mesh_name.contains("tolppa")
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
	water=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=Vector2(180,180);plane.subdivide_width=80;plane.subdivide_depth=80
	water.mesh=plane;water.position=Vector3(0,water_level,-20)
	water_mat=ShaderMaterial.new();water_mat.shader=load("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("water_normal",load("res://assets/extracted/sandcastle_water_normal.png"))
	water.material_override=water_mat;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)

func _make_player()->void:
	player=CharacterBody3D.new();player.name="Shark";player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	player.collision_layer=2;player.collision_mask=1;add_child(player);player.position=START
	var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=0.55;shape.shape=sphere;player.add_child(shape)
	visual=Node3D.new();visual.set_script(load("res://scripts/shark.gd"));player.add_child(visual)
	camera=Camera3D.new();camera.fov=17;camera.near=0.1;camera.far=500;add_child(camera);camera.current=true
	_camera_update(1.0)

func _make_targets()->void:
	# Original scenery with a small original procedural swimmer for the gameplay loop.
	for i in 35:
		var target:=Node3D.new();add_child(target)
		var x:=rng.randf_range(-4.2,4.2)
		var z:float=-24.0-float(i%10)*3.0
		if i>=20:x=rng.randf_range(-36,30);z=-3.2+rng.randf_range(-2.0,2.0)
		target.position=Vector3(x,water_level,z)
		var body:=MeshInstance3D.new();var capsule:=CapsuleMesh.new();capsule.radius=0.14;capsule.height=0.65;capsule.radial_segments=6;capsule.rings=2;body.mesh=capsule
		body.rotation.x=PI/2;target.add_child(body)
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.62,0.22+rng.randf()*0.25,0.10);body.material_override=mat
		var head:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=0.15;sphere.height=0.30;sphere.radial_segments=6;sphere.rings=3;head.mesh=sphere;head.position=Vector3(0,0.1,-0.4)
		var skin:=StandardMaterial3D.new();skin.albedo_color=Color(0.62,0.46,0.31);head.material_override=skin;target.add_child(head)
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
	var hint:=Label.new();hint.text="WASD 移动  ·  空格冲刺  ·  E / 左键吞噬";hint.add_theme_font_size_override("font_size",13);v.add_child(hint)
	var bottom:=PanelContainer.new();root.add_child(bottom);bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_top=-59;bottom.offset_left=24;bottom.offset_right=-24;bottom.offset_bottom=-18;_panel_style(bottom)
	feed_label=Label.new();feed_label.add_theme_font_size_override("font_size",15);bottom.add_child(feed_label)
	notice=Label.new();notice.position=Vector2(26,150);notice.modulate=Color(0.94,0.77,0.40);root.add_child(notice)
	notice.text="洪水已进入街区。捕食成长，冲刺撞开车辆。"
	help=PanelContainer.new();root.add_child(help);help.position=Vector2(24,210);_panel_style(help);help.visible=false
	var text:=Label.new();text.text="操作说明\n\nWASD / 方向键 / 左摇杆：移动\n空格 / 手柄 B：冲刺（1 秒，冷却 5 秒）\nE / 鼠标左键 / 手柄 A：吞噬\nPageUp / PageDown：升降水位\nT：切换清澈 / 浑浊水体\nTab：切换像素效果\n鼠标滚轮：镜头远近\nR：重新开始    Esc：暂停\nF11：全屏    F1：收起说明\n\n成长后冲刺可以破坏墙片。";help.add_child(text)
	var corner:=Label.new();root.add_child(corner);corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);corner.offset_left=-330;corner.offset_top=26;corner.offset_right=-24;corner.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;corner.text="本地验证原型  01\nF1 操作说明  ·  T 水体对比"
	pause_label=Label.new();root.add_child(pause_label);pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER);pause_label.offset_left=-100;pause_label.offset_top=-30;pause_label.add_theme_font_size_override("font_size",32);pause_label.text="已暂停  /  ESC";pause_label.visible=false

func _panel_style(panel:PanelContainer)->void:
	var s:=StyleBoxFlat.new();s.bg_color=Color(0.045,0.065,0.07,0.9);s.border_color=Color(0.44,0.44,0.32);s.border_width_top=1;s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=8;s.content_margin_bottom=8;panel.add_theme_stylebox_override("panel",s)

func _unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("boost") and not paused:_start_boost()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:paused=not paused;pause_label.visible=paused
			KEY_F1:help.visible=not help.visible
			KEY_R:get_tree().reload_current_scene()
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
	water_mat.set_shader_parameter("shallow_color",Color(0.08,0.48,0.48) if clear_water else Color(0.16,0.34,0.32))
	water_mat.set_shader_parameter("deep_color",Color(0.025,0.23,0.32) if clear_water else Color(0.035,0.12,0.13))
	water_mat.set_shader_parameter("clarity",0.16 if clear_water else 0.32)

func _physics_process(dt:float)->void:
	if not ready_done or paused:return
	elapsed+=dt
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
	player.position.y=water_level-0.12*growth
	if dir.length()>0.1:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-dir.x,-dir.z),minf(1.0,dt*12.0))
	player.move_and_slide()
	if boost_time>0:
		for i in player.get_slide_collision_count():
			var hit:KinematicCollision3D=player.get_slide_collision(i)
			var body=hit.get_collider()
			if body and body.has_meta("visual"):
				var m:MeshInstance3D=body.get_meta("visual")
				if m in destructibles and (m.get_meta("car",false) or growth>=1.25):_break_piece(m)
	if Input.is_action_pressed("bite") and bite_timer<=0:_bite()
	for target in targets:
		if not is_instance_valid(target):continue
		target.position.y=water_level+sin(elapsed*3+float(target.get_meta("phase")))*0.035
		var away:Vector3=target.position-player.position;away.y=0
		if away.length()<6 and away.length()>0.1:target.position+=away.normalized()*dt*0.7
	water_mat.set_shader_parameter("player_pos",player.position)
	water_mat.set_shader_parameter("player_speed",player.velocity.length())
	_camera_update(dt)
	status.text="吞噬 %02d   /   体型 %.2f×   /   破坏 %02d"%[eaten,growth,wrecked]
	boost_bar.value=100.0*(1.0-clampf((cooldown-boost_time)/5.0,0,1))
	feed_label.text="洪水现场   /   水位 %.1fm    ·    %s    |    PAGE↑↓ 调水位    |    %02d:%02d"%[water_level,"清澈水体" if clear_water else "末世浑水",int(elapsed)/60,int(elapsed)%60]

func _camera_update(dt:float)->void:
	camera_target=camera_target.lerp(player.position,1.0-exp(-dt/0.3))
	var dist:float=zoom+(growth-1.0)*22.0
	var offset:=Vector3(0.5,0.707106,-0.5)*dist
	shake=maxf(0,shake-dt*2.0)
	camera.position=camera_target+offset+Vector3(sin(elapsed*85),cos(elapsed*72),0)*shake*0.35
	camera.look_at(camera_target)

func _bite()->void:
	bite_timer=0.35
	var found:=false
	for i in range(targets.size()-1,-1,-1):
		var t:=targets[i]
		if is_instance_valid(t) and t.position.distance_to(player.position)<2.8*growth:
			targets.remove_at(i);t.queue_free();eaten+=1;growth=minf(2.8,1.0+eaten*0.065);found=true
	visual.scale=Vector3.ONE*growth
	if found:
		shake=0.25;notice.text="吞噬成功 · 体型增长。"+("现在可以冲刺撞碎墙片。" if growth>=1.25 else "继续捕食以解锁墙片破坏。")
	else:notice.text="靠近水面目标后吞噬。"

func _start_boost()->void:
	if cooldown<=0:
		boost_time=1.0;cooldown=6.0;notice.text="冲刺！撞击车辆，或撕开墙片。"

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
	var start:=m.global_position
	var away:Vector3=(start-player.position).normalized()
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(m,"global_position",start+away*2.0+Vector3(0,-2.0,0),0.8)
	tween.tween_property(m,"rotation",m.rotation+Vector3(0.4,0.3,1.1),0.8)
	if not m.get_meta("car",false):tween.chain().tween_callback(m.hide)
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
		trace["eaten_after_bite"]=eaten;trace["growth"]=growth
		var press:=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=true
		Input.parse_input_event(press);await get_tree().create_timer(0.08).timeout
		press=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=false;Input.parse_input_event(press)
		trace["boost_started"]=cooldown>0
		water_level=1.6;await get_tree().create_timer(0.1).timeout;trace["water_y"]=water.position.y
		_toggle_water();trace["water_mode_changed"]=clear_water
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
		trace["passed"]=trace.movement_distance>1.0 and eaten>0 and growth>1.0 and trace.boost_started and absf(water.position.y-1.6)<0.01 and clear_water and trace.wall_collision and wrecked>0
		trace["fps"]=Engine.get_frames_per_second()
		FileAccess.open("res://research/smoke_test.json",FileAccess.WRITE).store_string(JSON.stringify(trace,"  "))
		print("SMOKE_TEST ",trace)
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	image.save_png("res://research/smoke_preview.png" if smoke_test else "res://research/prototype_preview.png")
	print("CAPTURE_SAVED")
	get_tree().quit(0 if not smoke_test or trace.get("passed",false) else 1)
