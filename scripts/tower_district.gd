extends Node3D
var game:Node3D
var towers:Array[Dictionary]=[]

func setup(owner_game:Node3D)->void:
	game=owner_game
	var source:Array=game.buildings["JapanStage/JapanHighriser"].parts
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
	var shape:=CollisionShape3D.new();shape.shape=node.mesh.create_trimesh_shape();body.add_child(shape);game.solids[node.get_instance_id()]=body

func _make_tower(source:Array,source_box:AABB,pos:Vector3,height:float)->void:
	var key:="FloodDefenseTower_%d"%towers.size()
	game.buildings[key]={"parts":[],"hits":0,"collapsing":false}
	var stretch:=Basis.from_scale(Vector3(6.4/source_box.size.x,height/source_box.size.y,6.4/source_box.size.z))
	var origin:=Vector3(source_box.get_center().x,source_box.position.y,source_box.get_center().z)
	for part:MeshInstance3D in source:
		var copy:=MeshInstance3D.new();copy.mesh=part.mesh;copy.name="TowerFacade"
		add_child(copy);copy.transform=Transform3D(stretch*part.global_basis,pos+stretch*(part.global_position-origin))
		_register(copy,key)
	# A continuous rooftop supports guards and collision-safe roof recovery.
	var roof:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(6.5,0.18,6.5);roof.mesh=box
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.29,0.30,0.28);mat.roughness=1;roof.material_override=mat
	add_child(roof);roof.position=pos+Vector3.UP*(height+0.09);roof.name="DefenseRoof";_register(roof,key)
	var guards:Array=[]
	for offset in [Vector3(-2.9,0,0),Vector3(2.9,0,0),Vector3(0,0,-2.9),Vector3(0,0,2.9)]:
		var npc:Node3D=game.fx.make_civilian(game.roof_targets,true,"military");game.add_child(npc)
		npc.position=pos+offset+Vector3.UP*(height+0.24);npc.set_meta("rooftop",true);npc.set_meta("roof_support",roof);npc.set_meta("phase",float(game.roof_targets));npc.set_meta("tower_guard",true)
		game.targets.append(npc);game.roof_targets+=1;guards.append(npc)
	towers.append({"key":key,"roof":roof,"guards":guards,"position":pos,"height":height+0.18})
