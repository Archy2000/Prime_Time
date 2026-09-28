extends Node3D
## Surface foam: distinct from ballistic spray. Reads completed solver snapshots only.
const CAPACITY:=1200
var sim:RefCounted
var water_y:=1.15
var particles:Array[Dictionary]=[]
var swimmer_times:Dictionary={}
var rng:=RandomNumberGenerator.new()
var mesh:MultiMeshInstance3D
var material:ShaderMaterial
var clock:=0.0
var emission_timer:=0.0
var cursor:=0
var born:=0
var contact_groups:=0

func setup(field:RefCounted,level:float)->void:
	sim=field;water_y=level;rng.seed=39172
	mesh=MultiMeshInstance3D.new();var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	var plane:=PlaneMesh.new();plane.size=Vector2(2,2);mm.mesh=plane
	mm.instance_count=CAPACITY;mm.visible_instance_count=0;mesh.multimesh=mm
	material=ShaderMaterial.new();material.shader=preload("res://shaders/whitewater_particles.gdshader");material.render_priority=4
	material.set_shader_parameter("wave_field",sim.texture);material.set_shader_parameter("field_origin",sim.origin);material.set_shader_parameter("field_extent",sim.extent)
	material.set_shader_parameter("terrain_clipping",sim.extent<100)
	mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.extra_cull_margin=2.0
	add_child(mesh)

func emit_swimmer(id:int,pos:Vector3,velocity:Vector3,size:float)->void:
	var speed:=Vector2(velocity.x,velocity.z).length()
	if speed<0.12 or size>0.7:return
	if clock-float(swimmer_times.get(id,-1.0))<0.15:return
	swimmer_times[id]=clock
	var direction:=Vector3(velocity.x,0,velocity.z).normalized();var side:=direction.cross(Vector3.UP)
	for sign_value in [-1.0,1.0]:
		var center:Vector3=pos+side*sign_value*size*0.55+direction*size*0.15
		for dot in 5:
			_spawn(center+Vector3(rng.randf_range(-0.04,0.04),0,rng.randf_range(-0.04,0.04)),rng.randf_range(0.16,0.23),rng.randf_range(1.2,1.7),Vector2(velocity.x,velocity.z)*0.08)

func _spawn(pos:Vector3,state:float,scale_value:float,drift:Vector2)->void:
	if particles.size()>=CAPACITY:return
	pos.y=0
	particles.append({"p":pos,"state":state,"scale":scale_value,"drift":drift})
	born+=1

func update(dt:float,level:float)->void:
	water_y=level;clock+=dt;emission_timer+=dt
	material.set_shader_parameter("water_y",water_y)
	if emission_timer>=0.14:
		emission_timer=0;_emit_contacts()
	for i in range(particles.size()-1,-1,-1):
		var particle:Dictionary=particles[i]
		particle.state-=dt*0.2 # Whitewater_Update: state decays at 0.2 per second.
		if particle.state<=0.01:particles.remove_at(i);continue
		var flow:Vector3=sim.sample_surface(particle.p)
		var drift:Vector2=Vector2(flow.x,flow.z)*0.5+particle.drift
		particle.p+=Vector3(drift.x,0,drift.y)*dt
		particle.drift*=exp(-dt*2.5)
	mesh.multimesh.visible_instance_count=particles.size()
	for i in particles.size():
		var particle:Dictionary=particles[i]
		# VS bytecode: 0.1*(1-exp(-4*state)), opacity saturate(10*state)*0.4.
		var radius:float=0.1*(1.0-exp(-4.0*particle.state))*particle.scale
		mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(radius,1,radius)),particle.p))
		mesh.multimesh.set_instance_color(i,Color(1,1,1,clampf(particle.state*10,0,1)*0.4))
	for id in swimmer_times.keys():
		if clock-float(swimmer_times[id])>4:swimmer_times.erase(id)

func _emit_contacts()->void:
	var camera:=get_viewport().get_camera_3d()
	if not camera:return
	var emitted:=0
	var total:int=sim.N*sim.N
	var space:=get_world_3d().direct_space_state
	for step in 1400:
		cursor=(cursor+37)%total
		var i:=cursor;var x:int=i%sim.N;var z:int=i/sim.N
		if x<1 or z<1 or x>=sim.N-1 or z>=sim.N-1 or sim.rgba[i*4+3]>0.5:continue
		if water_y+sim.rgba[i*4]-sim.rgba[i*4+1]<0.06:continue
		var wall:=Vector3(sim.rgba[(i+1)*4+3]-sim.rgba[(i-1)*4+3],0,sim.rgba[(i+sim.N)*4+3]-sim.rgba[(i-sim.N)*4+3])
		if wall.length_squared()<0.1:continue
		var impact:float=sim.flow_rgba[i*4+3]
		if rng.randf()>0.14+impact*0.65:continue
		var pos:=Vector3(sim.origin.x+x*sim.cell,water_y+sim.rgba[i*4]+0.025,sim.origin.y+z*sim.cell)
		if camera.is_position_behind(pos) or not get_viewport().get_visible_rect().has_point(camera.unproject_position(pos)):continue
		wall=wall.normalized()
		# AABB cells only identify candidates; ray hit anchors foam on actual collision geometry.
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos-wall*sim.cell,pos+wall*sim.cell*2.0,1))
		if hit.is_empty():continue
		var normal:Vector3=hit.normal;normal.y=0;normal=normal.normalized()
		if normal.length_squared()<0.5:continue
		var center:Vector3=hit.position+normal*0.055
		var tangent:=normal.cross(Vector3.UP)
		for dot in 12:
			_spawn(center+tangent*rng.randf_range(-0.065,0.065)+normal*rng.randf_range(0,0.06),rng.randf_range(0.30,0.58),rng.randf_range(1.25,1.85),Vector2(normal.x,normal.z)*rng.randf_range(0.025,0.075))
		contact_groups+=1;emitted+=1
		if emitted>=5:return
