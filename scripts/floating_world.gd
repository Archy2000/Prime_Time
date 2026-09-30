extends Node3D
## Shared flow-following boats, beacons and lightweight post-destruction stones.
var game:Node3D
var sources:Dictionary={}
var floats:Array[Dictionary]=[]
var stones:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var emitted_stones:=0
var clock:=0.0
var feedback:=0.0
const MAX_STONES:=650

func setup(owner_game:Node3D)->void:
	game=owner_game;rng.seed=2209
	var scene:Node3D=load("res://assets/sand_floats/sand_floats.gltf").instantiate()
	for node in scene.get_children():
		if node is MeshInstance3D and node.name!="Rock_01":sources[String(node.name)]=node.duplicate()
	scene.free()
	# Boats occupy the open north/south canal; anchored beacons mark the route.
	for spec in [["Boat_01",Vector3(0,0,-58),3.8],["WoodenBoat_01",Vector3(1.5,0,-15),4.0],["Boat_01",Vector3(-20,0,-3),3.4],["WoodenBoat_01",Vector3(23,0,-3),3.6],["Buoy_01",Vector3(-3,0,-52),2.4],["Buoy_01",Vector3(3,0,-20),2.4],["Buoy_01",Vector3(-16,0,-5),2.4],["Buoy_01",Vector3(19,0,-5),2.4]]:
		_make_float(spec[0],spec[1],spec[2])

func _make_float(key:String,pos:Vector3,size:float)->void:
	var node:MeshInstance3D=sources[key].duplicate();node.name=key+"_floating";node.scale=Vector3.ONE*size;node.position=Vector3(pos.x,game.water_level,pos.z);add_child(node)
	var buoy:bool=key=="Buoy_01"
	if buoy:
		var hull:=StandardMaterial3D.new();hull.albedo_color=Color(0.72,0.09,0.035);hull.roughness=0.8;node.material_override=hull
	node.set_meta("source_mesh",key.to_lower());node.set_meta("broken",false);node.set_meta("required_growth",1.0)
	game.destructibles.append(node)
	var body:=AnimatableBody3D.new();body.sync_to_physics=false;body.collision_layer=1;body.set_meta("visual",node);node.add_child(body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=node.mesh.get_aabb().size;shape.shape=box;shape.position=node.mesh.get_aabb().get_center();body.add_child(shape);game.solids[node.get_instance_id()]=body
	if buoy:
		var light:=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=0.045;ball.height=0.09;light.mesh=ball;light.position.y=0.67
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color(1,0.16,0.05);mat.emission_enabled=true;mat.emission=Color(1,0.08,0.015);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light.material_override=mat;node.add_child(light);node.set_meta("beacon_light",light)
	floats.append({"node":node,"anchor":pos,"buoy":buoy,"size":size,"velocity":Vector3.ZERO,"phase":rng.randf()*TAU})

func accept_piece(body:RigidBody3D)->void:
	# Keep this building's actual clipped triangles, UVs and materials.
	var mesh:MeshInstance3D=body.get_child(0)
	var xf:Transform3D=mesh.global_transform
	mesh.reparent(self);mesh.global_transform=xf
	var center:Vector3=mesh.mesh.get_aabb().get_center()
	var pos:Vector3=xf*center
	stones.append({"node":mesh,"basis":xf.basis,"center":center,"p":pos,"v":body.linear_velocity*0.3,"size":(xf.basis*mesh.mesh.get_aabb().size).length(),"age":0.0,"life":rng.randf_range(50,70),"angle":0.0,"floating":false})
	emitted_stones+=1
	while stones.size()>MAX_STONES:
		stones[0].node.queue_free();stones.pop_front()

func _move_in_water(pos:Vector3,step:Vector3)->Vector3:
	var end:=pos+step
	var from:=Vector3(pos.x,game.water_level+0.08,pos.z);var to:=Vector3(end.x,from.y,end.z)
	var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
	if not hit.is_empty():return pos
	end.x=clampf(end.x,-58,58);end.z=clampf(end.z,-74,41);return end

func update(dt:float)->void:
	clock+=dt;feedback+=dt
	for f in floats:
		var node:MeshInstance3D=f.node
		if node.get_meta("broken",false):continue
		var field:Vector3=game.wave_sim.sample_surface(node.position)
		var wanted:=Vector3(field.x,0,field.z)*0.65
		var delta:Vector3=node.position-game.player.position;delta.y=0
		if delta.length()<game.growth+1.3:wanted+=delta.normalized()*1.3
		if f.buoy:
			var tether:Vector3=f.anchor-node.position;tether.y=0;wanted+=tether*1.6
		f.velocity=f.velocity.lerp(wanted,1.0-exp(-dt*2))
		# Their own collider is at the ray origin; exclude it for drift tests.
		var end:Vector3=node.position+f.velocity*dt
		var ray:=PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*0.15,end+Vector3.UP*0.15,1)
		ray.exclude=[game.solids[node.get_instance_id()].get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():node.position=end
		node.position.x=clampf(node.position.x,-56,56);node.position.z=clampf(node.position.z,-72,39)
		node.position.y=lerpf(node.position.y,game.water_level+field.y-0.04,minf(1,dt*8))
		var r:float=0.22*f.size
		var dx:float=(game.wave_sim.sample_surface(node.position+Vector3.RIGHT*r).y-game.wave_sim.sample_surface(node.position-Vector3.RIGHT*r).y)/(2*r)
		var dz:float=(game.wave_sim.sample_surface(node.position+Vector3.BACK*r).y-game.wave_sim.sample_surface(node.position-Vector3.BACK*r).y)/(2*r)
		node.rotation.x=lerpf(node.rotation.x,clampf(dz,-0.28,0.28),minf(1,dt*4));node.rotation.z=lerpf(node.rotation.z,clampf(-dx,-0.28,0.28),minf(1,dt*4))
		if f.buoy:node.get_meta("beacon_light").visible=sin(clock*3+f.phase)>0.2
		if feedback>0.18:
			game.wave_sim.disturb(node.position,0.5,0.005,0.015,Vector2(f.velocity.x,f.velocity.z)*0.025)
			if not f.buoy:game.water_fx.swimmer(node.get_instance_id(),node.position,f.velocity,0.5)
	if feedback>0.18:feedback=0
	for i in range(stones.size()-1,-1,-1):
		var s:Dictionary=stones[i];s.age+=dt
		if s.age>s.life:s.node.queue_free();stones.remove_at(i);continue
		var field:Vector3=game.wave_sim.sample_surface(s.p);var surface:float=game.water_level+field.y
		if not s.floating:
			s.v.y-=9.8*dt;s.p+=s.v*dt
			if s.p.y<=surface+s.size*0.1:s.floating=true;s.v.y=0
		else:
			var wanted:=Vector3(field.x,0,field.z)*0.8
			s.v=s.v.lerp(wanted,1-exp(-dt*2.5));s.v.y=0
			s.p=_move_in_water(s.p,s.v*dt)
			s.p.y=lerpf(s.p.y,surface-s.size*0.12,minf(1,dt*9))
			s.angle+=dt*(field.x-field.z)*0.3
	for s in stones:
		var fade:float=clampf((s.life-s.age)/5,0,1)
		var basis:Basis=Basis(Vector3.UP,s.angle)*s.basis.scaled(Vector3.ONE*fade)
		s.node.transform=Transform3D(basis,s.p-basis*s.center)

func _exit_tree()->void:
	for source in sources.values():source.free()
