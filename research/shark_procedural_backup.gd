extends Node3D

var tail: Node3D

func _ready() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color=Color(0.20,0.25,0.25)
	dark.roughness=0.86
	var belly := StandardMaterial3D.new()
	belly.albedo_color=Color(0.48,0.48,0.40)
	belly.roughness=1.0
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments=10
	sphere.rings=5
	sphere.radius=0.48
	sphere.height=0.96
	body.mesh=sphere
	body.scale=Vector3(1.0,0.75,2.6)
	body.material_override=dark
	add_child(body)
	_fin([Vector3(0,0,-0.3),Vector3(0,1.0,0.05),Vector3(0,0,0.65)],dark,self)
	_fin([Vector3(-0.22,0,0),Vector3(-1.15,-0.15,0.65),Vector3(-0.3,-0.1,0.7)],dark,self)
	_fin([Vector3(0.22,0,0),Vector3(1.15,-0.15,0.65),Vector3(0.3,-0.1,0.7)],dark,self)
	tail=Node3D.new()
	tail.position.z=1.0
	add_child(tail)
	_fin([Vector3(0,0,0),Vector3(0,0.78,1.0),Vector3(0,0.0,0.65),Vector3(0,-0.5,0.9)],dark,tail)
	for side in [-1,1]:
		var eye:=MeshInstance3D.new()
		var e:=SphereMesh.new()
		e.radius=0.05;e.height=0.1;e.radial_segments=8;e.rings=4
		eye.mesh=e
		eye.position=Vector3(side*0.28,0.16,-0.9)
		var black:=StandardMaterial3D.new();black.albedo_color=Color(0.015,0.02,0.02)
		eye.material_override=black
		add_child(eye)

func _fin(points: Array, mat: Material, parent: Node3D) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for j in [0,i,i+1]:st.add_vertex(points[j])
		for j in [i+1,i,0]:st.add_vertex(points[j]+Vector3(0.035,0,0))
	st.generate_normals()
	var m:=MeshInstance3D.new();m.mesh=st.commit();m.material_override=mat;parent.add_child(m)

func _process(_dt:float)->void:
	if tail:tail.rotation.y=sin(Time.get_ticks_msec()*0.008)*0.26
