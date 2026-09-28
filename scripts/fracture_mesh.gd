extends RefCounted
## Clip the original triangles, interpolating UVs/normals, so chunks reconstruct
## the actual facade/roof instead of replacing it with unrelated small stones.
static func split(source:MeshInstance3D)->Array:
	var bounds:=source.mesh.get_aabb()
	var axes:=[0,1,2]
	axes.sort_custom(func(a:int,b:int):return bounds.size[a]>bounds.size[b])
	var cuts:=[1,1,1]
	cuts[axes[0]]=3;cuts[axes[1]]=2
	var result:Array=[]
	for x in cuts[0]:
		for y in cuts[1]:
			for z in cuts[2]:
				var low:=bounds.position+bounds.size*Vector3(float(x)/cuts[0],float(y)/cuts[1],float(z)/cuts[2])
				var high:=low+bounds.size/Vector3(cuts[0],cuts[1],cuts[2])
				var output:=ArrayMesh.new()
				for surface in source.mesh.get_surface_count():
					var arrays:=source.mesh.surface_get_arrays(surface)
					var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
					var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
					var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
					if indices.is_empty():
						for i in verts.size():indices.append(i)
					var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
					var count:=0
					for t in range(0,indices.size(),3):
						var polygon:Array=[]
						for j in 3:
							var i:int=indices[t+j]
							polygon.append([verts[i],normals[i] if not normals.is_empty() else Vector3.UP,uvs[i] if not uvs.is_empty() else Vector2.ZERO])
						for axis in 3:
							if cuts[axis]==1:continue
							polygon=clip(polygon,axis,low[axis],true)
							polygon=clip(polygon,axis,high[axis],false)
						for j in range(1,polygon.size()-1):
							var a:Vector3=polygon[0][0];var b:Vector3=polygon[j][0];var c:Vector3=polygon[j+1][0]
							if (b-a).cross(c-a).length_squared()<0.00000001:continue
							for vertex in [polygon[0],polygon[j],polygon[j+1]]:
								st.set_normal(vertex[1]);st.set_uv(vertex[2]);st.add_vertex(vertex[0]);count+=1
					if count>0:
						st.set_material(source.get_active_material(surface));st.commit(output)
				if output.get_surface_count()>0:result.append(output)
	return result

static func clip(polygon:Array,axis:int,edge:float,positive:bool)->Array:
	var result:Array=[]
	if polygon.is_empty():return result
	var a:Array=polygon[-1]
	var da:float=(a[0][axis]-edge)*(1.0 if positive else -1.0)
	for b:Array in polygon:
		var db:float=(b[0][axis]-edge)*(1.0 if positive else -1.0)
		if (da>=0)!=(db>=0):
			var t:float=da/(da-db)
			result.append([a[0].lerp(b[0],t),a[1].lerp(b[1],t).normalized(),a[2].lerp(b[2],t)])
		if db>=0:result.append(b)
		a=b;da=db
	return result
