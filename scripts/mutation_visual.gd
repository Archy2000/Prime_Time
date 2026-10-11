extends Node3D
## Mutations derived from the existing PS1 shark, retaining its mesh/UV/rig.
var hydra_model:Node3D
var primary_socket:Node3D
var bite_left:=0.0
var heads:Array[Node3D]=[]
var arms:Array[Array]=[]
var tips:Array[Vector3]=[]
var grab_point:=Vector3.ZERO
var grab_left:=0.0
var clock:=0.0
var zombie_materials:Array[Dictionary]=[]
var purple:StandardMaterial3D
var bone:StandardMaterial3D

func material(color:Color,glow:bool=false)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.86
	if glow:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.5
	return m

func mesh_node(parent:Node3D,shape:Mesh,pos:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
	var n:=MeshInstance3D.new();n.mesh=shape;n.position=pos;n.scale=size;n.material_override=mat;parent.add_child(n)
	return n

func ball(parent:Node3D,pos:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
	var s:=SphereMesh.new();s.radius=0.5;s.height=1.0;s.radial_segments=10;s.rings=5
	return mesh_node(parent,s,pos,size,mat)

func rebuild(ranks:Dictionary)->void:
	for entry in zombie_materials:
		if is_instance_valid(entry.mesh):entry.mesh.set_surface_override_material(entry.surface,entry.original)
	zombie_materials.clear()
	for child in get_children():child.free()
	heads.clear();arms.clear();tips.clear()
	purple=material(Color(0.43,0.24,0.58));bone=material(Color(0.92,0.84,0.61))
	var level:int=ranks.get("hydra",0)
	var source_shark:Node3D=get_parent().get_node_or_null("PS1Shark")
	if source_shark:source_shark.show()
	hydra_model=null;primary_socket=null
	if level>0:
		var count:int=[0,2,3,5,9][level]
		hydra_model=preload("res://scripts/source_shark_hydra.gd").new()
		add_child(hydra_model)
		hydra_model.setup(source_shark,count,int(ranks.get("zombie",0))>0)
		primary_socket=hydra_model.sockets[0]
		for i in range(1,hydra_model.sockets.size()):heads.append(hydra_model.sockets[i])
	var tentacle:int=ranks.get("kraken",0)
	for i in tentacle*2:
		var segments:Array=[]
		for j in 7:
			var tube:=CylinderMesh.new();tube.top_radius=0.10;tube.bottom_radius=0.13;tube.height=1;tube.radial_segments=7
			segments.append(mesh_node(self,tube,Vector3.ZERO,Vector3.ONE,purple))
		arms.append(segments);tips.append(Vector3.ZERO)
	var undead:int=ranks.get("zombie",0)
	if undead>0:
		var source:Node=get_parent().get_node_or_null("PS1Shark")
		if source:
			for n in source.find_children("*","MeshInstance3D"):
				for surface in n.mesh.get_surface_count():
					var original:Material=n.get_active_material(surface)
					if original is StandardMaterial3D:
						zombie_materials.append({"mesh":n,"surface":surface,"original":original})
						var skin:StandardMaterial3D=original.duplicate();skin.albedo_color=Color(0.43,0.68,0.33);n.set_surface_override_material(surface,skin)
		for i in 4+undead:
			var spike:=CylinderMesh.new();spike.top_radius=0;spike.bottom_radius=0.10;spike.height=0.48;spike.radial_segments=5
			mesh_node(self,spike,Vector3(0,0.43,-0.55+i*0.19),Vector3.ONE,bone)
			for side in [-1,1]:
				ball(self,Vector3(side*0.34,0.20,-0.48+i*0.18),Vector3(0.09,0.37,0.09),bone)
		ball(self,Vector3(0,0.48,-0.9),Vector3(0.3,0.11,0.4),material(Color(0.35,1,0.13),true))
	animate(0.0)

func mouths()->Array[Vector3]:
	var result:Array[Vector3]=[]
	for h in heads:result.append(h.global_position)
	return result

func primary_mouth()->Vector3:
	if is_instance_valid(primary_socket):return primary_socket.global_position
	return get_parent().to_global(Vector3(0,0.12,-0.6))

func bite()->void:
	bite_left=0.3

func grab(pos:Vector3)->void:
	grab_point=pos;grab_left=0.42

func animate(dt:float)->void:
	clock+=dt;grab_left=maxf(0,grab_left-dt)
	bite_left=maxf(0,bite_left-dt)
	if is_instance_valid(hydra_model):hydra_model.update_sockets()
	for i in arms.size():
		var side:float=-1.0 if i%2==0 else 1.0
		var row:=i/2
		var start:=Vector3(side*0.28,0.08,-0.2+row*0.27)
		var end:=Vector3(side*(1.8+row*0.18),0.2+sin(clock*2+i)*0.25,-0.9+row*0.65)
		if grab_left>0 and i<2:end=to_local(grab_point)
		var previous:=start
		for j in 7:
			var t:=float(j+1)/7
			var p:=start.lerp(end,t)+Vector3(0,sin(t*PI)*0.38,sin(t*TAU+clock*3+i)*0.18*t)
			var segment:MeshInstance3D=arms[i][j]
			segment.position=(previous+p)*0.5
			var direction:=p-previous
			var up:=direction.normalized()
			var right:=up.cross(Vector3.FORWARD).normalized()
			if right.length_squared()<0.1:right=Vector3.RIGHT
			segment.basis=Basis(right,up,right.cross(up).normalized())
			segment.scale=Vector3(1.0-t*0.75,maxf(0.01,direction.length()),1.0-t*0.75)
			previous=p
		tips[i]=end
