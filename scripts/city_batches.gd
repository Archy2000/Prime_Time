extends Node3D
## Batch repeated static geometry in local cells; original nodes own gameplay.
const CELL_SIZE:=24.0
var batches:=0
var instances:=0
var scaled_meshes:Dictionary={}

func _scaled_mesh(source:Mesh,scale:Vector3)->Mesh:
	var key:=str(source.get_instance_id(),"/",scale.snapped(Vector3.ONE*0.000001))
	if scaled_meshes.has(key):return scaled_meshes[key]
	var mesh:=ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays:=source.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():vertices[i]*=scale
		arrays[Mesh.ARRAY_VERTEX]=vertices
		if arrays[Mesh.ARRAY_NORMAL]!=null:
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for i in normals.size():normals[i]=(normals[i]/scale).normalized()
			arrays[Mesh.ARRAY_NORMAL]=normals
		if arrays[Mesh.ARRAY_TANGENT]!=null:
			var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
			for i in range(0,tangents.size(),4):
				var tangent:Vector3=(Vector3(tangents[i],tangents[i+1],tangents[i+2])*scale).normalized()
				tangents[i]=tangent.x;tangents[i+1]=tangent.y;tangents[i+2]=tangent.z
			arrays[Mesh.ARRAY_TANGENT]=tangents
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays)
		mesh.surface_set_material(surface,source.surface_get_material(surface))
	scaled_meshes[key]=mesh
	return mesh

func setup(city:Node3D)->void:
	var groups:Dictionary={}
	for node in city.get_children():
		if not node is MeshInstance3D or not node.visible or node.mesh==null:continue
		if node.get_surface_override_material_count()>0:
			var overridden:=false
			for surface in node.mesh.get_surface_count():
				if node.get_surface_override_material(surface)!=null:overridden=true
			if overridden:continue
		var pos:Vector3=node.global_position
		var scale:Vector3=node.global_basis.get_scale().abs()
		if minf(scale.x,minf(scale.y,scale.z))<0.000001:continue
		var material_id:int=node.material_override.get_instance_id() if node.material_override else 0
		var key:=str(node.mesh.get_instance_id(),"/",scale.snapped(Vector3.ONE*0.000001),"/",material_id,"/",node.cast_shadow,"/",node.layers,"/",floori(pos.x/CELL_SIZE),"/",floori(pos.z/CELL_SIZE))
		if not groups.has(key):groups[key]=[]
		groups[key].append(node)
	for group:Array in groups.values():
		if group.size()<2:continue
		var source:MeshInstance3D=group[0]
		var batch:=MultiMeshInstance3D.new()
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
		# Compatibility instancing does not inverse-transpose nonuniform scale
		# for normals. Bake scale once and use rotation-only instance bases.
		mm.mesh=_scaled_mesh(source.mesh,source.global_basis.get_scale().abs());mm.instance_count=group.size()
		batch.multimesh=mm;batch.material_override=source.material_override
		batch.cast_shadow=source.cast_shadow;batch.layers=source.layers
		add_child(batch)
		for index in group.size():
			var node:MeshInstance3D=group[index]
			var transform:Transform3D=node.global_transform
			var scale:Vector3=transform.basis.get_scale().abs()
			transform.basis=Basis(transform.basis.x/scale.x,transform.basis.y/scale.y,transform.basis.z/scale.z)
			mm.set_instance_transform(index,transform)
			node.set_meta("render_layers",node.layers)
			node.set_meta("render_shadow",node.cast_shadow)
			# Layers hide only the individual renderer; visible and collision remain
			# intact for roof support, obstacle masks and destruction checks.
			node.layers=0;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_changed.connect(_sync_visibility.bind(node,mm,index,transform))
			instances+=1
		batches+=1

func _sync_visibility(node:MeshInstance3D,mm:MultiMesh,index:int,transform:Transform3D)->void:
	mm.set_instance_transform(index,transform if node.is_visible_in_tree() else Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),transform.origin))
