extends Node3D
## High resolution, world-space crest ribbons; separate from underwater caustics.
var audio:Node3D
var sim:RefCounted
var water_y:=1.15
var clock:=0.0
var tracks:Dictionary={}
var material:ShaderMaterial
var spray:MultiMeshInstance3D
var droplets:Array=[]
var rng:=RandomNumberGenerator.new()
var emitted:=0
const MAX_DROPS:=384
var breaches:Array[Dictionary]=[]
var breach_count:=0
var last_breach:Dictionary={}
var surf_timer:=0.0
var surf_phase:=0
var surf_emitted:=0

func setup(field:RefCounted,level:float)->void:
	sim=field;water_y=level;rng.seed=791
	audio=preload("res://scripts/water_audio.gd").new();add_child(audio)
	material=ShaderMaterial.new();material.shader=load("res://research/v11_before/wake_ribbon.gdshader");material.render_priority=4
	material.set_shader_parameter("wave_field",sim.texture);material.set_shader_parameter("field_origin",sim.origin);material.set_shader_parameter("field_extent",sim.extent)
	material.set_shader_parameter("terrain_clipping",sim.extent<100)
	spray=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=6;sphere.rings=3;mm.mesh=sphere;mm.instance_count=MAX_DROPS;mm.visible_instance_count=0;spray.multimesh=mm
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color("deeeec");m.vertex_color_use_as_albedo=true;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;spray.material_override=m;spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(spray)

func swimmer(id:int,pos:Vector3,velocity:Vector3,size:float)->void:
	if id==0:audio.swim(pos,velocity,size)
	var speed:=Vector2(velocity.x,velocity.z).length()
	if speed<0.6:return
	var direction:=Vector3(velocity.x,0,velocity.z).normalized()
	if not tracks.has(id):
		var mesh:=MeshInstance3D.new();mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh)
		tracks[id]={"mesh":mesh,"points":[],"last":pos-direction*0.4,"distance":0.0,"spray_time":0.0,"life":lerpf(0.55,1.65,smoothstep(0.30,1.0,size))}
	var track:Dictionary=tracks[id]
	var distance:float=pos.distance_to(track.last)
	if distance>6.0*size:track.points.clear();track.last=pos;return
	if distance<maxf(0.12,0.22*size):return
	track.distance+=distance;track.last=pos
	track.points.push_front({"pos":pos,"direction":direction,"born":clock,"size":size,"speed":speed,"u":track.distance})
	while track.points.size()>64:track.points.pop_back()
	if speed>2.5 and clock-track.spray_time>0.06:
		track.spray_time=clock
		var side:=direction.cross(Vector3.UP)
		for sign_value in [-1.0,1.0]:
			var p:Vector3=pos+direction*0.65*size+side*sign_value*0.40*size;p.y=water_y+sim.sample_surface(p).y+0.10
			_drop(p,side*sign_value*rng.randf_range(0.35,0.9)+direction*speed*0.12+Vector3.UP*rng.randf_range(0.6,1.3),rng.randf_range(0.022,0.045)*sqrt(size))

func splash(pos:Vector3,strength:float)->void:
	audio.splash(pos,strength)
	for i in mini(32,int(strength*15)+8):
		var angle:=rng.randf()*TAU;var d:=Vector3(cos(angle),0,sin(angle))
		var p:=pos+d*rng.randf_range(0.15,0.5);p.y=water_y+0.1
		_drop(p,d*rng.randf_range(0.5,1.5)*strength+Vector3.UP*rng.randf_range(1,2.4)*sqrt(strength),rng.randf_range(0.025,0.055))

func breach(pos:Vector3,size:float,vertical_speed:float,landing:bool)->void:
	audio.breach(pos,size,vertical_speed,landing)
	var impact:float=clampf(absf(vertical_speed)/14.0,0.65,1.4)
	var radius:float=size*(1.05 if landing else 0.8)
	var amplitude:float=(0.075+size*0.075)*impact*(1.0 if landing else 0.65)
	var life:float=1.65+sqrt(size)*0.35
	var center:=Vector3(pos.x,water_y+0.075,pos.z)
	# Center displacement plus an outward impulse rim feeds the height/flow solver.
	sim.disturb(center,radius,-amplitude*0.65 if landing else amplitude*0.5,0.35*size)
	for i in 12:
		var angle:float=TAU*i/12.0;var d:=Vector3(cos(angle),0,sin(angle))
		sim.disturb(center+d*radius,0.55+size*0.32,amplitude,0.28*size,Vector2(d.x,d.z)*amplitude*2.2)
	var node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2.ONE*radius*8.0;plane.subdivide_width=64;plane.subdivide_depth=64;node.mesh=plane
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/breach_splash.gdshader");mat.render_priority=5
	mat.set_shader_parameter("wave_field",sim.texture);mat.set_shader_parameter("field_origin",sim.origin);mat.set_shader_parameter("field_extent",sim.extent)
	mat.set_shader_parameter("radius",radius);mat.set_shader_parameter("height",size*impact*(1.55 if landing else 1.15));mat.set_shader_parameter("life",life);mat.set_shader_parameter("seed",rng.randf()*TAU)
	node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=size*impact*1.55;add_child(node);node.position=center
	breaches.append({"node":node,"material":mat,"age":0.0,"life":life})
	while breaches.size()>6:breaches[0].node.queue_free();breaches.remove_at(0)
	var count:int=mini(140,int((40+size*25)*impact*(1.0 if landing else 0.8)))
	# Reserve space so swimming spray cannot suppress a landing burst.
	while droplets.size()+count>MAX_DROPS:droplets.pop_front()
	for i in count:
		var angle:float=TAU*float(i)/count+rng.randf_range(-0.1,0.1);var d:=Vector3(cos(angle),0,sin(angle))
		var p:Vector3=center+d*radius*rng.randf_range(0.35,0.9)
		p.y=water_y+sim.sample_surface(p).y+0.16
		var velocity:Vector3=d*rng.randf_range(1.4,3.0)*sqrt(size)*impact+Vector3.UP*rng.randf_range(3.0,5.5)*sqrt(size)*impact
		_drop(p,velocity,rng.randf_range(0.04,0.085)*sqrt(size),clampf(velocity.y/4.9+0.15,0.8,2.7),9.8)
	breach_count+=1
	last_breach={"landing":landing,"size":size,"radius":radius,"amplitude":amplitude,"drops":count,"life":life,"vertical_speed":vertical_speed}

func _drop(pos:Vector3,velocity:Vector3,size:float,life:float=0.65,gravity:float=5.0)->void:
	if droplets.size()>=MAX_DROPS:return
	droplets.append({"p":pos,"v":velocity,"size":size,"age":0.0,"life":life,"gravity":gravity});emitted+=1

func _process(dt:float)->void:
	# Only completed snapshots are read; never read worker-owned height/solid arrays.
	surf_timer+=dt
	if surf_timer>=0.14:
		surf_timer=0;_surface_spray()
	if not sim:return
	clock+=dt;material.set_shader_parameter("clock",clock);material.set_shader_parameter("water_y",water_y)
	for i in range(breaches.size()-1,-1,-1):
		var b:Dictionary=breaches[i];b.age+=dt;b.node.position.y=water_y+0.075;b.material.set_shader_parameter("age",b.age)
		if b.age>=b.life:b.node.queue_free();breaches.remove_at(i)
	for id in tracks.keys():
		var track:Dictionary=tracks[id]
		while not track.points.is_empty() and clock-track.points.back().born>track.life:track.points.pop_back()
		if track.points.is_empty():track.mesh.queue_free();tracks.erase(id);continue
		_build(track)
	for i in range(droplets.size()-1,-1,-1):
		var drop:Dictionary=droplets[i];drop.age+=dt;drop.v.y-=drop.gravity*dt;drop.p+=drop.v*dt
		if drop.age>drop.life or drop.p.y<water_y+sim.sample_surface(drop.p).y-0.05:droplets.remove_at(i)
	spray.multimesh.visible_instance_count=droplets.size()
	for i in droplets.size():
		var drop:Dictionary=droplets[i];var size:float=drop.size*(1.0-drop.age/drop.life*0.4)
		spray.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size,size*1.5,size)),drop.p))
		spray.multimesh.set_instance_color(i,Color(1,1,1,minf(1,(drop.life-drop.age)*5)))

func _surface_spray()->void:
	if not sim or droplets.size()>96:return
	var camera:=get_viewport().get_camera_3d()
	if not camera:return
	var count:=0
	surf_phase=(surf_phase+1)%3
	for z in range(2+surf_phase,sim.N-2,3):
		for x in range(2,sim.N-2,2):
			var i:int=z*sim.N+x
			var strength:float=sim.flow_rgba[i*4+3]
			if strength<0.16 or sim.rgba[i*4+3]>0.5:continue
			# Spray is reserved for impacts against solid geometry, not every foam cell.
			var nx:float=sim.rgba[(i-1)*4+3]-sim.rgba[(i+1)*4+3]
			var nz:float=sim.rgba[(i-sim.N)*4+3]-sim.rgba[(i+sim.N)*4+3]
			var away:=Vector3(nx,0,nz)
			if away.length_squared()<0.1:continue
			var p:=Vector3(sim.origin.x+x*sim.cell,water_y+sim.rgba[i*4]+0.06,sim.origin.y+z*sim.cell)
			if camera.is_position_behind(p) or not get_viewport().get_visible_rect().has_point(camera.unproject_position(p)):continue
			if rng.randf()>strength*0.7:continue
			away=away.normalized()
			for drop in 2:
				_drop(p+away*rng.randf_range(0.0,0.12),away*rng.randf_range(0.2,0.65)+Vector3.UP*rng.randf_range(0.8,1.7)*sqrt(strength),rng.randf_range(0.018,0.038),0.65,5.0)
				surf_emitted+=1
			count+=1
			if count>=6:return

func _build(track:Dictionary)->void:
	if track.points.size()<2:return
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	for sign_value in [-1.0,1.0]:
		var base:=vertices.size()
		for i in track.points.size():
			var p:Dictionary=track.points[i];var age:float=clock-p.born
			var side:Vector3=p.direction.cross(Vector3.UP)*sign_value
			var spread:float=p.size*(0.46+age*0.65)
			var detail_scale:float=lerpf(0.55,1.0,smoothstep(0.30,1.0,p.size))
			var width:float=p.size*(0.48+age*0.14)*detail_scale
			var center:Vector3=p.pos+side*spread-p.direction*0.12
			var travelled:float=track.distance-p.u
			var fade:float=pow(maxf(0,1-age/track.life),1.4)*exp(-travelled/(p.size*4.0))*clampf(p.speed/5,0,1)*detail_scale
			# Taper both ends; no rectangular end cap or texture stamp.
			fade*=minf(1,float(i+1)/2.0)*minf(1,float(track.points.size()-i)/3.0)
			for u in [0.0,0.25,0.5,0.75,1.0]:
				vertices.append(center+side*(u-0.5)*width);uv.append(Vector2(u,p.u));colors.append(Color(minf(1,p.speed/10),0,0,fade))
			if i>0:
				for j in 4:
					var k:int=base+i*5+j;indices.append_array(PackedInt32Array([k-5,k-4,k,k-4,k+1,k]))
	# Curved bow lip joins the two side crests at the front of the swimmer.
	var head:Dictionary=track.points.front();var head_age:float=clock-head.born
	var bow_alpha:float=clampf((0.25-head_age)*6,0,1)*clampf(head.speed/6,0,1)
	bow_alpha*=lerpf(0.32,1.0,smoothstep(0.30,1.0,head.size))
	var bow_base:=vertices.size();var lateral:Vector3=head.direction.cross(Vector3.UP)
	for segment in 17:
		var angle:float=-PI/2+PI*float(segment)/16
		var outward:Vector3=head.direction*cos(angle)+lateral*sin(angle)
		var center:Vector3=head.pos+head.direction*cos(angle)*head.size*0.91+lateral*sin(angle)*head.size*0.48
		for u in [0.0,0.25,0.5,0.75,1.0]:
			vertices.append(center+outward*(u-0.5)*head.size*0.50);uv.append(Vector2(u,angle*head.size+clock*0.13));colors.append(Color(minf(1.0,head.size),0,0,bow_alpha))
		if segment>0:
			for j in 4:
				var k:int=bow_base+segment*5+j;indices.append_array(PackedInt32Array([k-5,k-4,k,k-4,k+1,k]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);track.mesh.mesh=mesh
