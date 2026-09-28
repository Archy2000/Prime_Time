extends Node3D
## Source ROLLA meshes/textures with Godot impulses, dust, splatter and capture animation.
var game:Node3D
var library:Dictionary={}
var civilians:Array[MeshInstance3D]=[]
var fragments:Array[RigidBody3D]=[]
var captures:Array[Dictionary]=[]
var rings:Array[Dictionary]=[]
var splats:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var spawned_fragments:=0
var splash_count:=0
var swallow_count:=0
var last_crumble_sound:=-10.0
var last_meal_sound:=-10.0
var last_swish:=-10.0
var transient_count:=0

func setup(owner_game:Node3D)->void:
	game=owner_game;rng.seed=729
	var source:Node3D=load("res://assets/effects/fracture_parts.gltf").instantiate()
	for child in source.get_children():
		if not child is MeshInstance3D:continue
		library[String(child.name)]=child.duplicate()
		if "man_casual" in child.name or "man_business" in child.name or "woman_scientist" in child.name:
			civilians.append(child.duplicate())
	source.free()

func make_civilian(index:int,standing:bool=false)->Node3D:
	var root:=Node3D.new()
	if civilians.is_empty():return root
	var source:MeshInstance3D=civilians[index%civilians.size()]
	var person:=source.duplicate() as MeshInstance3D
	var bounds:AABB=person.transform*person.mesh.get_aabb()
	var factor:float=0.95/maxf(bounds.size.y,0.01)
	person.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),Vector3.ZERO)*person.transform
	person.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	root.add_child(person)
	if standing:return root
	person.rotation.x=-PI/2.0
	person.position.y=0.06
	person.position.z=0.45
	var vest:=MeshInstance3D.new();var vb:=BoxMesh.new();vb.size=Vector3(0.27,0.13,0.27);vest.mesh=vb;vest.position=Vector3(0,0.075,-0.12)
	var vm:=StandardMaterial3D.new();vm.albedo_color=Color(0.65,0.20,0.045);vm.roughness=1.0;vest.material_override=vm;root.add_child(vest)
	return root

func update(dt:float)->void:
	for i in range(captures.size()-1,-1,-1):
		var c:Dictionary=captures[i];c.age+=dt
		var victim:Node3D=c.node
		if not is_instance_valid(victim):captures.remove_at(i);continue
		var t:float=clampf(c.age/c.duration,0,1)
		var mouth:Vector3=game.player.position-game.visual.global_basis.z.normalized()*game.growth*0.85
		var off:=Vector3(sin(t*TAU+c.phase),0,cos(t*TAU+c.phase))*sin(t*PI)*0.32
		victim.global_position=c.start.lerp(mouth,t*t)+off+Vector3.UP*sin(t*PI)*0.8
		victim.scale=Vector3.ONE*lerpf(1.0,0.025,t*t)
		victim.rotation+=Vector3(1.8,4.2,0.7)*dt
		if t>=1:
			var pos:Vector3=victim.global_position
			victim.queue_free();captures.remove_at(i);swallow_count+=1
			blood(pos)
			if absf(pos.y-game.water_level)<0.9:splash(pos,0.75)
			game._finish_meal(pos)
	for i in range(rings.size()-1,-1,-1):
		var r:Dictionary=rings[i];r.age+=dt
		var t:float=r.age/r.life
		r.node.position.y=game.water_level+0.10
		r.material.set_shader_parameter("progress",t)
		if t>=1:r.node.queue_free();rings.remove_at(i)
	for i in range(splats.size()-1,-1,-1):
		var s:Dictionary=splats[i];s.age+=dt
		s.node.position.y=game.water_level+0.045
		s.node.scale=Vector3.ONE*(1.0+s.age*0.12)
		var col:Color=s.material.albedo_color;col.a=0.64*clampf(1.0-s.age/8.0,0,1);s.material.albedo_color=col
		if s.age>8:s.node.queue_free();splats.remove_at(i)
	for i in range(fragments.size()-1,-1,-1):
		var b:=fragments[i]
		if not is_instance_valid(b):fragments.remove_at(i);continue
		var age:float=float(b.get_meta("age",0.0))+dt;b.set_meta("age",age)
		var local_water:Vector3=game.wave_sim.sample_surface(b.position)
		var surface_y:float=game.water_level+local_water.y
		if not b.get_meta("splashed",false) and b.position.y<surface_y+0.05 and b.linear_velocity.y<-0.4:
			b.set_meta("splashed",true);splash(b.position,0.5)
		if b.position.y<surface_y:
			b.linear_velocity*=exp(-dt*1.0);b.angular_velocity*=exp(-dt*1.5)
			b.apply_central_force(Vector3(local_water.x-b.linear_velocity.x,4.0,local_water.z-b.linear_velocity.z)*b.mass)
		if age>12 or b.position.y<-8:
			b.queue_free();fragments.remove_at(i)

func swallow(victim:Node3D)->void:
	if victim.get_meta("captured",false):return
	victim.set_meta("captured",true)
	captures.append({"node":victim,"start":victim.global_position,"age":0.0,"duration":0.32,"phase":rng.randf()*TAU})
	if absf(victim.global_position.y-game.water_level)<0.9:splash(victim.global_position,0.5)
	if game.elapsed-last_meal_sound>0.15:
		sound("qdeath1" if rng.randf()>0.5 else "qdeath3",victim.global_position,-18);last_meal_sound=game.elapsed

func splash(pos:Vector3,strength:float=1.0)->void:
	splash_count+=1
	game.wave_sim.disturb(pos,0.65*strength+0.3,0.12*strength,0.18*strength)
	game.water_fx.splash(pos,strength)
	var ring:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2.ONE*(2.8+strength*2.0);ring.mesh=plane
	var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/splash_ring.gdshader");mat.render_priority=3
	ring.material_override=mat;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring);ring.position=Vector3(pos.x,game.water_level+0.1,pos.z)
	rings.append({"node":ring,"material":mat,"age":0.0,"life":0.9+strength*0.25})
	while rings.size()>36:
		rings[0].node.queue_free();rings.remove_at(0)

func blood(pos:Vector3)->void:
	var plane:=MeshInstance3D.new();var quad:=PlaneMesh.new();quad.size=Vector2(2.0,2.0);plane.mesh=quad
	var mat:=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/effects/rollasplat1.png");mat.albedo_color=Color(0.34,0.015,0.012,0.65)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.render_priority=2
	plane.material_override=mat;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(plane);plane.position=pos;plane.position.y=game.water_level+0.045;plane.rotation.y=rng.randf()*TAU
	splats.append({"node":plane,"material":mat,"age":0.0})
	while splats.size()>20:splats[0].node.queue_free();splats.remove_at(0)
	burst(pos,Color(0.35,0.018,0.009),18,0.55,0.035,0.09,2.6,"")

func fracture(mesh_node:MeshInstance3D,impulse:Vector3,amount:int=8)->void:
	var box:AABB=mesh_node.global_transform*mesh_node.mesh.get_aabb()
	var center:=box.get_center()
	var family:="lowrise2Wall_cell"
	if "highriser" in mesh_node.name:family="highriserWall_cell"
	elif "lowriseWall" in mesh_node.name:family="lowriseWall_cell"
	var parts:Array[MeshInstance3D]=[]
	for k in library:
		if String(k).begins_with(family):parts.append(library[k])
	mesh_node.hide()
	for i in amount:
		var fragment:MeshInstance3D=parts[i%parts.size()].duplicate() if not parts.is_empty() else mesh_node.duplicate()
		for c in fragment.get_children():c.free()
		var raw:=fragment.mesh.get_aabb();var dim:float=maxf(raw.size.x,maxf(raw.size.y,raw.size.z))
		var target_size:float=rng.randf_range(0.38,0.95)
		var scale_factor:float=target_size/maxf(dim,0.01)
		fragment.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_factor),-raw.get_center()*scale_factor)
		fragment.visible=true
		var b:=RigidBody3D.new();b.mass=0.45;b.collision_layer=4;b.collision_mask=1;b.linear_damp=0.14;b.angular_damp=0.3
		add_child(b);b.add_child(fragment)
		var shape:=CollisionShape3D.new();var bs:=BoxShape3D.new();bs.size=Vector3.ONE*target_size*0.48;shape.shape=bs;b.add_child(shape)
		b.position=center+Vector3(rng.randf_range(-0.45,0.45)*box.size.x,rng.randf_range(-0.35,0.4)*box.size.y,rng.randf_range(-0.45,0.45)*box.size.z)
		b.position.y=maxf(b.position.y,game.water_level+0.35)
		b.linear_velocity=impulse*0.35+Vector3(rng.randf_range(-3.8,3.8),rng.randf_range(3.0,6.2),rng.randf_range(-3.8,3.8))
		b.angular_velocity=Vector3(rng.randf_range(-6,6),rng.randf_range(-6,6),rng.randf_range(-6,6))
		fragments.append(b);spawned_fragments+=1
	while fragments.size()>110:fragments[0].queue_free();fragments.remove_at(0)
	if transient_count<32:
		burst(center,Color(0.18,0.17,0.14),18,1.8,0.8,2.8,1.5,"smoke_bally")
		burst(center,Color(0.40,0.34,0.25),22,1.2,0.25,0.9,2.7,"smoke_single")
	splash(Vector3(center.x,game.water_level,center.z),1.3)
	if game.elapsed-last_crumble_sound>0.3:sound("buildingCrumble",center,-11);last_crumble_sound=game.elapsed

func launch_car(mesh_node:MeshInstance3D,impulse:Vector3)->void:
	var xf:=mesh_node.global_transform
	var copy:=mesh_node.duplicate() as MeshInstance3D
	for c in copy.get_children():c.free()
	var box:=copy.mesh.get_aabb();var center:Vector3=xf*box.get_center()
	var b:=RigidBody3D.new();b.mass=1.2;b.collision_layer=4;b.collision_mask=1;b.linear_damp=0.3
	add_child(b);b.position=center;b.add_child(copy)
	copy.transform=Transform3D(xf.basis,xf.origin-center)
	var shape:=CollisionShape3D.new();var bs:=BoxShape3D.new();bs.size=(xf*box).size*0.65;shape.shape=bs;b.add_child(shape)
	b.linear_velocity=impulse*0.9+Vector3.UP*5;b.angular_velocity=Vector3(2.0,1.5,3.0);fragments.append(b)
	mesh_node.hide();splash(center,1.2);sound("carbreak",center,-12)

func burst(pos:Vector3,color:Color,count:int,life:float,min_size:float,max_size:float,speed:float,tex:String)->void:
	var p:=CPUParticles3D.new();p.amount=maxi(1,count);p.lifetime=life;p.one_shot=true;p.explosiveness=0.95;p.local_coords=false;p.direction=Vector3.UP;p.spread=65
	p.initial_velocity_min=speed*0.4;p.initial_velocity_max=speed;p.gravity=Vector3(0,-5.5,0) if tex.is_empty() else Vector3(0.15,0.4,0.1)
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=0.5
	p.scale_amount_min=min_size;p.scale_amount_max=max_size
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.vertex_color_use_as_albedo=true;mat.roughness=1.0
	var mesh:Mesh
	if not tex.is_empty():
		var q:=QuadMesh.new();q.size=Vector2.ONE;mesh=q
		mat.albedo_texture=load("res://assets/effects/"+tex+".png");mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.render_priority=4
	else:
		var b:=BoxMesh.new();b.size=Vector3(0.8,1.8,0.8);mesh=b
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0,mat);p.mesh=mesh
	var grad:=Gradient.new();grad.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0)]);grad.offsets=PackedFloat32Array([0,0.6,1]);p.color_ramp=grad
	var curve:=Curve.new();curve.add_point(Vector2(0,0.35));curve.add_point(Vector2(0.25,1));curve.add_point(Vector2(1,1.8 if not tex.is_empty() else 0.05));p.scale_amount_curve=curve
	add_child(p);p.position=pos;transient_count+=1
	get_tree().create_timer(life+0.2).timeout.connect(func():if is_instance_valid(p):p.queue_free();transient_count-=1)

func sound(key:String,pos:Vector3,volume:float)->void:
	var audio:=AudioStreamPlayer3D.new();audio.stream=load("res://assets/effects/"+key+".wav");audio.volume_db=volume;audio.unit_size=18;audio.max_distance=250;audio.pitch_scale=rng.randf_range(0.93,1.06)
	add_child(audio);audio.position=pos;audio.play();audio.finished.connect(audio.queue_free)

func popup(pos:Vector3,text:String,color:Color)->void:
	var label:=Label3D.new();label.text=text;label.font_size=72;label.pixel_size=0.007;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.modulate=color;label.outline_size=12
	add_child(label);label.position=pos+Vector3.UP*1.1
	var tween:=create_tween().set_parallel(true);tween.tween_property(label,"position:y",label.position.y+1.7,0.8);tween.tween_property(label,"modulate:a",0.0,0.5).set_delay(0.3);tween.chain().tween_callback(label.queue_free)

func _exit_tree()->void:
	for node in library.values():node.free()
	for node in civilians:node.free()
