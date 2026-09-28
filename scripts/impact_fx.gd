extends Node3D
## Source ROLLA meshes/textures with Godot impulses, dust, splatter and capture animation.
var game:Node3D
var library:Dictionary={}
var civilians:Array[MeshInstance3D]=[]
var police_models:Array[MeshInstance3D]=[]
var military_models:Array[MeshInstance3D]=[]
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
const MAX_FRAGMENTS:=180
const MAX_SPLATS:=240
var fracture_cache:Dictionary={}
var blood_left:=0.0
const BLOOD_TRAIL_LENGTH:=2.5
const BLOOD_TRAIL_TIME:=0.65
var blood_travel_left:=0.0
var blood_previous:=Vector3.ZERO
var blood_distance:=0.0
var blood_stamps:=0
var blood_drops:Array[Dictionary]=[]
var dust_last:=-10.0
var chunks_released:=0
var smoke_clouds:Array[Dictionary]=[]

func setup(owner_game:Node3D)->void:
	game=owner_game;rng.seed=729
	var source:Node3D=load("res://assets/effects/fracture_parts.gltf").instantiate()
	for child in source.get_children():
		if not child is MeshInstance3D:continue
		library[String(child.name)]=child.duplicate()
	source.free()
	var humans:Node3D=load("res://assets/characters/humans/humans.gltf").instantiate()
	for child in humans.get_children():
		if not child is MeshInstance3D:continue
		if String(child.name).begins_with("man_") or String(child.name).begins_with("woman_"):civilians.append(child.duplicate())
		elif String(child.name).begins_with("police") and "assembled" in child.name:police_models.append(child.duplicate())
		elif child.name=="military_assembled":military_models.append(child.duplicate())
	humans.free()
	# Cache unique facade meshes at load time, avoiding clipping work during impact.
	for node:MeshInstance3D in game.destructibles:
		if not game.node_building.has(node.get_instance_id()):continue
		var key:int=node.mesh.get_instance_id()
		if not fracture_cache.has(key):fracture_cache[key]=preload("res://scripts/fracture_mesh.gd").split(node)

func make_civilian(index:int,standing:bool=false,role:String="civilian")->Node3D:
	var root:=Node3D.new()
	if civilians.is_empty():return root
	var choices:Array[MeshInstance3D]=police_models if role=="police" else military_models if role=="military" else civilians
	var source:MeshInstance3D=choices[(int(index/4) if role=="police" else index)%choices.size()]
	var person:=source.duplicate() as MeshInstance3D
	var bounds:AABB=person.transform*person.mesh.get_aabb()
	var factor:float=0.95/maxf(bounds.size.y,0.01)
	person.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),Vector3.ZERO)*person.transform
	person.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	root.add_child(person)
	root.set_script(preload("res://scripts/civilian.gd"))
	root.set_meta("role",role);root.set_meta("appearance",String(source.name))
	root.setup(person,index,standing)
	if role!="civilian":root.setup_armed(role)
	if standing:return root
	person.rotation.x=-PI/2.0
	person.position.y=0.06
	person.position.z=0.45
	var vest:=MeshInstance3D.new();var vb:=BoxMesh.new();vb.size=Vector3(0.27,0.13,0.27);vest.mesh=vb;vest.position=Vector3(0,0.075,-0.12)
	var vm:=StandardMaterial3D.new();vm.albedo_color=Color(0.65,0.20,0.045);vm.roughness=1.0;vest.material_override=vm;root.add_child(vest)
	return root

func update(dt:float)->void:
	_update_blood(dt)
	for i in range(smoke_clouds.size()-1,-1,-1):
		var cloud:Dictionary=smoke_clouds[i];cloud.age+=dt
		var t:float=cloud.age/cloud.life
		cloud.node.position+=cloud.velocity*dt
		cloud.node.scale=Vector3.ONE*cloud.size*lerpf(0.35,1.65,smoothstep(0,1,t))
		cloud.material.albedo_color.a=(1.0-smoothstep(0.55,1.0,t))*0.92
		if t>=1:cloud.node.queue_free();smoke_clouds.remove_at(i)
	for i in range(captures.size()-1,-1,-1):
		var c:Dictionary=captures[i];c.age+=dt
		var victim:Node3D=c.node
		if not is_instance_valid(victim):captures.remove_at(i);continue
		var t:float=clampf(c.age/c.duration,0,1)
		var mouth:Vector3=game.visual.global_position-game.visual.global_basis.z.normalized()*game.growth*0.85
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
		if s.water:
			var flow:Vector3=game.wave_sim.sample_surface(s.node.position)
			var drift:=Vector3(flow.x,0,flow.z).limit_length(1.2)*0.3
			var next:Vector3=s.node.position+drift*dt
			# Do not advect the cloud through a wall.
			var ray:=PhysicsRayQueryParameters3D.create(s.node.position,next,1)
			if drift.length_squared()>0.0001 and get_world_3d().direct_space_state.intersect_ray(ray).is_empty():s.node.position=next
			s.node.position.y=game.water_level+0.065
			var spread:float=1.0+1.8*(1.0-exp(-s.age*0.42))
			s.node.scale=Vector3(spread,1.0,spread*(1.0+minf(0.25,drift.length()*s.age)))
			s.material.set_shader_parameter("age",s.age)
		elif is_instance_valid(s.support) and s.support.get_meta("broken",false):
			s.node.queue_free();splats.remove_at(i);continue
		else:
			var fade:float=1.0-smoothstep(s.life*0.72,s.life,s.age)
			var col:Color=s.material.albedo_color;col.a=s.opacity*fade;s.material.albedo_color=col
		if s.age>=s.life:s.node.queue_free();splats.remove_at(i)
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
		if age>34:
			b.scale=Vector3.ONE*maxf(0.02,(40.0-age)/6.0)
		if age>40 or b.position.y<-8:
			b.queue_free();fragments.remove_at(i)

func swallow(victim:Node3D)->void:
	if victim.get_meta("captured",false):return
	victim.set_meta("captured",true)
	game.npc_audio.stop_actor(victim)
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
	_stamp_blood(pos,1.6*game.growth,rng.randf()*TAU)
	# A brief residue from this meal, not ongoing bleeding from the shark.
	blood_previous=game.player.position;blood_distance=0.0
	blood_left=BLOOD_TRAIL_TIME;blood_travel_left=BLOOD_TRAIL_LENGTH
	for i in 12:
		if blood_drops.size()>=72:break
		var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=0.045;mesh.height=0.09;mesh.radial_segments=4;mesh.rings=2;node.mesh=mesh
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.43,0.025,0.012);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat
		add_child(node);node.position=pos+Vector3.UP*0.25;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blood_drops.append({"node":node,"velocity":game.player.velocity*0.23+Vector3(rng.randf_range(-2.8,2.8),rng.randf_range(1.8,4.5),rng.randf_range(-2.8,2.8)),"age":0.0})

func _stamp_blood(pos:Vector3,size:float,angle:float)->void:
	var origin:=pos;origin.y=maxf(pos.y+0.35,game.water_level+0.15)
	var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,Vector3(pos.x,-0.5,pos.z),1))
	var on_water:bool=hit.is_empty() or hit.position.y<game.water_level
	var support:Node=null
	if not hit.is_empty():support=hit.collider.get_meta("visual",null)
	var plane:=MeshInstance3D.new();var quad:=PlaneMesh.new();quad.size=Vector2(size*rng.randf_range(0.8,1.25),size*rng.randf_range(0.8,1.25));plane.mesh=quad
	var mat:=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/effects/rollasplat1.png");mat.albedo_color=Color(0.38+rng.randf()*0.08,0.035,0.012,0.82)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.render_priority=2
	plane.material_override=mat;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(plane)
	plane.position=Vector3(pos.x,game.water_level+0.065 if on_water else hit.position.y+0.025,pos.z);plane.rotation.y=angle
	if not on_water:
		var normal:Vector3=hit.normal
		if normal.dot(Vector3.UP)<0.98 and normal.dot(Vector3.UP)>0.3:
			var tangent:=Vector3.RIGHT.slide(normal).normalized();plane.basis=Basis(tangent,normal,tangent.cross(normal))
	var life:float=rng.randf_range(5.0,7.0) if on_water else 90.0
	var stain_material:Material=mat
	if on_water:
		quad.subdivide_width=8;quad.subdivide_depth=8
		var diffusion:=ShaderMaterial.new();diffusion.shader=preload("res://shaders/blood_diffusion.gdshader");diffusion.render_priority=2
		diffusion.set_shader_parameter("wave_field",game.wave_sim.texture)
		diffusion.set_shader_parameter("splat",mat.albedo_texture);diffusion.set_shader_parameter("lifetime",life);diffusion.set_shader_parameter("seed",rng.randf()*100.0)
		plane.material_override=diffusion;stain_material=diffusion
	splats.append({"node":plane,"material":stain_material,"age":0.0,"life":life,"opacity":0.82,"water":on_water,"support":support})
	blood_stamps+=1
	while splats.size()>MAX_SPLATS:splats[0].node.queue_free();splats.remove_at(0)

func _update_blood(dt:float)->void:
	if blood_left>0:
		var time_fraction:float=minf(1.0,blood_left/maxf(dt,0.00001))
		blood_left=maxf(0.0,blood_left-dt)
		var now:Vector3=game.player.position
		var delta:=now-blood_previous;delta.y=0
		var distance:=delta.length()
		var spacing:=0.38
		if distance>12.0 or game.airborne:
			blood_distance=0.0;blood_left=0.0;blood_travel_left=0.0
		elif distance>0.001:
			var travel:float=minf(distance*time_fraction,blood_travel_left)
			var at:float=spacing-blood_distance
			while at<=travel:
				var point:=blood_previous.lerp(now,at/distance)
				point+=Vector3(-delta.z,0,delta.x).normalized()*rng.randf_range(-0.15,0.15)
				var residue:float=clampf((blood_travel_left-at)/BLOOD_TRAIL_LENGTH,0,1)
				_stamp_blood(point,lerpf(0.2,0.85,residue)*minf(game.growth,1.4),atan2(delta.x,delta.z)+rng.randf_range(-0.5,0.5))
				at+=spacing
			blood_distance=fmod(blood_distance+travel,spacing)
			blood_travel_left=maxf(0.0,blood_travel_left-travel)
			if blood_travel_left<=0:blood_left=0.0
		blood_previous=now
	for i in range(blood_drops.size()-1,-1,-1):
		var drop:Dictionary=blood_drops[i];drop.age+=dt;drop.velocity.y-=9.8*dt
		var before:Vector3=drop.node.position;var after:Vector3=before+drop.velocity*dt
		var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(before,after,1))
		if not hit.is_empty() or after.y<=game.water_level or drop.age>3:
			_stamp_blood(hit.position if not hit.is_empty() else after,rng.randf_range(0.18,0.48),rng.randf()*TAU)
			drop.node.queue_free();blood_drops.remove_at(i)
		else:drop.node.position=after

func fracture(mesh_node:MeshInstance3D,impulse:Vector3,amount:int=8)->void:
	var box:AABB=mesh_node.global_transform*mesh_node.mesh.get_aabb()
	var center:=box.get_center()
	var key:int=mesh_node.mesh.get_instance_id()
	if not fracture_cache.has(key):fracture_cache[key]=preload("res://scripts/fracture_mesh.gd").split(mesh_node)
	var pieces:Array=fracture_cache[key]
	mesh_node.hide()
	for mesh:ArrayMesh in pieces:
		var fragment:=MeshInstance3D.new();fragment.mesh=mesh
		var local_center:=mesh.get_aabb().get_center()
		var world_center:Vector3=mesh_node.global_transform*local_center
		var b:=RigidBody3D.new();b.mass=clampf((mesh_node.global_transform*mesh.get_aabb()).get_volume()*0.5,0.35,8.0);b.collision_layer=4;b.collision_mask=1;b.linear_damp=0.24;b.angular_damp=0.5
		add_child(b);b.position=world_center;b.add_child(fragment)
		fragment.transform=Transform3D(mesh_node.global_basis,-(mesh_node.global_basis*local_center))
		var shape:=CollisionShape3D.new();var bs:=BoxShape3D.new();var size:Vector3=mesh_node.global_basis.get_scale()*mesh.get_aabb().size
		bs.size=Vector3(maxf(0.08,absf(size.x)),maxf(0.08,absf(size.y)),maxf(0.08,absf(size.z)))*0.85;shape.shape=bs
		shape.basis=mesh_node.global_basis.orthonormalized();b.add_child(shape)
		var outward:Vector3=(world_center-game.player.position).normalized()
		b.linear_velocity=impulse*0.3+outward*rng.randf_range(1.0,3.5)+Vector3.UP*rng.randf_range(0.8,2.8)
		if amount<8:b.linear_velocity*=0.55;b.linear_velocity.y-=1.5
		b.angular_velocity=Vector3(rng.randf_range(-2,2),rng.randf_range(-2,2),rng.randf_range(-2,2))
		fragments.append(b);spawned_fragments+=1;chunks_released+=1
	while fragments.size()>MAX_FRAGMENTS:fragments[0].queue_free();fragments.remove_at(0)
	if transient_count<28 and game.elapsed-dust_last>0.10:
		dust_last=game.elapsed
		_smoke_cloud(center)
		burst(center,Color(0.38,0.32,0.24),20,1.4,0.2,0.75,3.0,"smoke_single")
		burst(center,Color(0.32,0.28,0.21),18,1.3,0.06,0.17,4.0,"")
	if box.position.y<game.water_level+0.5:splash(Vector3(center.x,game.water_level,center.z),0.85)
	if game.elapsed-last_crumble_sound>0.3:sound("buildingCrumble",center,-11);last_crumble_sound=game.elapsed

func _smoke_cloud(pos:Vector3)->void:
	for i in 5:
		var node:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE;node.mesh=quad
		var mat:=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/effects/smoke_bally.png");mat.albedo_color=Color(0.022,0.021,0.018,0.9)
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.billboard_keep_scale=true;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.render_priority=4
		node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
		node.position=pos+Vector3(rng.randf_range(-0.8,0.8),rng.randf_range(0,0.7),rng.randf_range(-0.8,0.8));node.scale=Vector3.ONE*0.5
		smoke_clouds.append({"node":node,"material":mat,"age":0.0,"life":rng.randf_range(2.6,4.0),"size":rng.randf_range(1.8,3.3),"velocity":Vector3(rng.randf_range(-0.3,0.3),rng.randf_range(0.65,1.1),0.12)})
	while smoke_clouds.size()>70:smoke_clouds[0].node.queue_free();smoke_clouds.remove_at(0)

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
	while fragments.size()>MAX_FRAGMENTS:fragments[0].queue_free();fragments.remove_at(0)
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
		mat.albedo_texture=load("res://assets/effects/"+tex+".png");mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.billboard_keep_scale=true;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.render_priority=4
	else:
		var b:=BoxMesh.new();b.size=Vector3(0.8,1.8,0.8);mesh=b
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0,mat);p.mesh=mesh
	var grad:=Gradient.new();grad.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0)]);grad.offsets=PackedFloat32Array([0,0.6,1]);p.color_ramp=grad
	var curve:=Curve.new();curve.add_point(Vector2(0,0.35));curve.add_point(Vector2(0.25,1));curve.add_point(Vector2(1,1.8 if not tex.is_empty() else 0.05));p.scale_amount_curve=curve
	add_child(p);p.position=pos;transient_count+=1
	get_tree().create_timer(life+0.2,false).timeout.connect(func():if is_instance_valid(p):p.queue_free();transient_count-=1)

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
	for node in police_models:node.free()
	for node in military_models:node.free()


