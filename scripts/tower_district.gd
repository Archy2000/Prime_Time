extends Node3D
var game:Node3D
var towers:Array[Dictionary]=[]

func setup(owner_game:Node3D)->void:
	game=owner_game
	# The registry key contains a district, so copy only the first building.
	var source:Array=[]
	for part:MeshInstance3D in game.buildings["JapanStage/JapanHighriser"].parts:
		if String(part.get_meta("source_mesh", "")).begins_with("highriserwall"):
			source.append(part);break
	var source_box:AABB=source[0].global_transform*source[0].mesh.get_aabb()
	for part:MeshInstance3D in source:source_box=source_box.merge(part.global_transform*part.mesh.get_aabb())
	var occupied:Array[AABB]=[]
	for key in game.buildings:
		var parts:Array=game.buildings[key].parts
		var box:AABB=parts[0].global_transform*parts[0].mesh.get_aabb()
		for part:MeshInstance3D in parts:box=box.merge(part.global_transform*part.mesh.get_aabb())
		occupied.append(box)
	for z in [-62.0,-40.0,-18.0,18.0,32.0]:
		for x in [-36.0,36.0,-24.0,24.0,-48.0,48.0]:
			if towers.size()>=4:return
			var footprint:=AABB(Vector3(x-3.8,-1,z-3.8),Vector3(7.6,18,7.6))
			var clear:=true
			for box in occupied:
				if footprint.intersects(box):clear=false;break
			if not clear:continue
			_make_tower(source,source_box,Vector3(x,0,z),10.8+float(towers.size()%2)*1.2)
			occupied.append(footprint.grow(5.0))

func _register(node:MeshInstance3D,key:String)->void:
	node.set_meta("broken",false);node.set_meta("required_growth",2.3);node.set_meta("source_mesh","highriser_tower")
	game.destructibles.append(node);game.node_building[node.get_instance_id()]=key;game.buildings[key].parts.append(node)
	var body:=StaticBody3D.new();body.collision_layer=1;body.set_meta("visual",node);node.add_child(body)
	var shape:=CollisionShape3D.new();shape.shape=game.collision_mesh(node.mesh);body.add_child(shape);game.solids[node.get_instance_id()]=body

func _make_tower(source:Array,source_box:AABB,pos:Vector3,height:float)->void:
	var key:="FloodDefenseTower_%d"%towers.size()
	game.buildings[key]={"parts":[],"hits":0,"collapsing":false}
	# The imported mesh is an open facade. Close all four sides around a core.
	var facade:Mesh=_front_facade(source[0].mesh)
	var bounds:AABB=source[0].mesh.get_aabb()
	var wall_material:=StandardMaterial3D.new();wall_material.albedo_color=Color(0.48,0.47,0.43);wall_material.roughness=1
	_roof_piece(key,"TowerCore",pos+Vector3(0,height*0.5,0),Vector3(6.24,height,6.24),wall_material)
	var mapping:=Basis(Vector3(6.4/bounds.size.x,0,0),Vector3(0,0,0.20),Vector3(0,height/bounds.size.z,0))
	var origin:=Vector3(bounds.get_center().x,2.30,bounds.position.z)
	for side in 4:
		var rotation:=Basis(Vector3.UP,float(side)*PI*0.5)
		var copy:=MeshInstance3D.new();copy.mesh=facade;copy.name="TowerFacade"
		add_child(copy)
		copy.transform=Transform3D(rotation*mapping,pos+rotation*(Vector3(0,0,-3.2)-mapping*origin))
		_register(copy,key)
	# A continuous rooftop supports guards and collision-safe roof recovery.
	var roof:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(6.4,0.18,6.4);roof.mesh=box
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.58,0.56,0.49);mat.roughness=1;roof.material_override=mat
	add_child(roof);roof.position=pos+Vector3.UP*(height+0.09);roof.name="DefenseRoof";_register(roof,key)
	var trim:=StandardMaterial3D.new();trim.albedo_color=Color(0.72,0.71,0.64);trim.roughness=1
	_roof_piece(key,"RoofCornice",pos+Vector3(0,height-0.06,0),Vector3(6.46,0.16,6.46),trim)
	for axis in [0,2]:
		for side in [-1.0,1.0]:
			var center:=pos+Vector3(0,height+0.34,0);center[axis]+=side*3.12
			var size:=Vector3(6.4,0.32,6.4);size[axis]=0.16
			_roof_piece(key,"RoofParapet",center,size,trim)
	_roof_piece(key,"RoofAccess",pos+Vector3(0,height+0.56,0),Vector3(0.85,0.76,1.1),trim)
	var guards:Array=[]
	for offset in [Vector3(-2.9,0,0),Vector3(2.9,0,0),Vector3(0,0,-2.9),Vector3(0,0,2.9)]:
		var npc:Node3D=game.fx.make_civilian(game.roof_targets,true,"military");game.add_child(npc)
		npc.position=pos+offset+Vector3.UP*(height+0.24);npc.set_meta("rooftop",true);npc.set_meta("roof_support",roof);npc.set_meta("phase",float(game.roof_targets));npc.set_meta("tower_guard",true)
		game.targets.append(npc);game.roof_targets+=1;guards.append(npc)
	towers.append({"key":key,"roof":roof,"guards":guards,"position":pos,"height":height+0.18})

func _roof_piece(key:String,label:String,center:Vector3,size:Vector3,material:Material)->void:
	var piece:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
	piece.mesh=mesh;piece.material_override=material;piece.name=label
	add_child(piece);piece.position=center;_register(piece,key)

func _front_facade(source:Mesh)->ArrayMesh:
	var facade:=ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays:Array=source.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size():indices.append(index)
		var front:=PackedInt32Array()
		for triangle in range(0,indices.size(),3):
			var a:int=indices[triangle];var b:int=indices[triangle+1];var c:int=indices[triangle+2]
			if maxf(vertices[a].y,maxf(vertices[b].y,vertices[c].y))<=2.30:
				front.append_array(PackedInt32Array([a,b,c]))
		if front.is_empty():continue
		arrays[Mesh.ARRAY_INDEX]=front
		facade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material:Material=source.surface_get_material(surface).duplicate()
		if material is BaseMaterial3D:material.cull_mode=BaseMaterial3D.CULL_DISABLED
		facade.surface_set_material(facade.get_surface_count()-1,material)
	return facade


