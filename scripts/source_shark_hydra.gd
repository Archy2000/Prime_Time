extends Node3D
## Fork the existing shark's own skinned head meshes, preserving UVs/materials.
## Body, tail, fins, skeleton and authored animation remain the original nodes.
const HEAD_PARTS:Array[String]=["Head","Jaw","TeethTop"]
const ROOT_Z:=0.72
var source:Node3D
var skeleton:Skeleton3D
var original_parts:Array[MeshInstance3D]=[]
var generated_parts:Array[MeshInstance3D]=[]
var sockets:Array[Node3D]=[]
var specifications:Array[Vector3]=[] # yaw, lateral offset, longitudinal offset
var head_bone:=-1
var original_visibility:Array[bool]=[]

func setup(model:Node3D,count:int,undead:bool=false)->void:
	source=model;skeleton=source.find_child("Skeleton3D",true,false)
	head_bone=skeleton.find_bone("Head_2")
	if count==2:
		specifications=[Vector3(-0.32,-0.40,0),Vector3(0.32,0.40,0)]
	else:
		specifications=[Vector3.ZERO,Vector3(-0.66,-0.22,0),Vector3(0.66,0.22,0)]
		if count>=5:specifications.append_array([Vector3(-1.16,-0.30,-0.40),Vector3(1.16,0.30,-0.40)])
		if count>=9:specifications.append_array([Vector3(-1.75,-0.35,-1.05),Vector3(1.75,0.35,-1.05),Vector3(-2.15,-0.30,-1.80),Vector3(2.15,0.30,-1.80)])
	for name in HEAD_PARTS:
		var part:MeshInstance3D=skeleton.get_node(name)
		original_parts.append(part);original_visibility.append(part.visible)
		# Odd counts retain the real central head without touching its geometry.
		part.visible=count!=2
	for i in specifications.size():
		var tip:=Node3D.new();tip.name="OriginalSharkMouth_%d"%i;add_child(tip);sockets.append(tip)
		if count!=2 and i==0:continue
		for part in original_parts:
			var copy:=MeshInstance3D.new();copy.name="Mutation_%d_%s"%[i,part.name]
			copy.mesh=fork_mesh(part.mesh,specifications[i]);copy.skin=part.skin;copy.skeleton=NodePath("..")
			copy.transform=part.transform;skeleton.add_child(copy);generated_parts.append(copy)
			for surface in part.mesh.get_surface_count():
				var mat:StandardMaterial3D=part.get_active_material(surface).duplicate()
				if undead:mat.albedo_color=Color(0.43,0.68,0.33)
				copy.set_surface_override_material(surface,mat)
	update_sockets()

func fork_position(p:Vector3,spec:Vector3)->Vector3:
	# The original rear neck ring stays exactly in place. The authored skull,
	# jaw and teeth move rigidly; only the short neck transition is deformed.
	var weight:=smoothstep(ROOT_Z,1.30,p.z)
	var origin:=Vector3(0,0,ROOT_Z)
	var rotated:=Basis(Vector3.UP,spec.x)*(p-origin)+origin+Vector3(spec.y,0,spec.z)
	return p.lerp(rotated,weight)

func fork_mesh(mesh:Mesh,spec:Vector3)->ArrayMesh:
	var result:=ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface).duplicate(true)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var weight:=smoothstep(ROOT_Z,1.30,vertices[i].z)
			normals[i]=(Basis(Vector3.UP,spec.x*weight)*normals[i]).normalized()
			vertices[i]=fork_position(vertices[i],spec)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
		# Regenerate tangents only when the source has them; these textures use
		# albedo alone, but UV, skin indices, weights and face indices stay exact.
		if arrays[Mesh.ARRAY_TANGENT]!=null:arrays[Mesh.ARRAY_TANGENT]=null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func update_sockets()->void:
	if not is_instance_valid(skeleton):return
	var skinning:Transform3D=skeleton.get_bone_global_pose(head_bone)*skeleton.get_bone_global_rest(head_bone).affine_inverse()
	for i in sockets.size():
		var position_in_mesh:=fork_position(Vector3(0,-0.21,2.28),specifications[i])
		sockets[i].global_position=skeleton.to_global(skinning*position_in_mesh)

func _exit_tree()->void:
	for part in generated_parts:
		if is_instance_valid(part):part.free()
	for i in original_parts.size():
		if is_instance_valid(original_parts[i]):original_parts[i].visible=original_visibility[i]
