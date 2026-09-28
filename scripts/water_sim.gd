extends RefCounted
## Persistent world-space wave field with reflecting solid boundaries.
const N:=192
const EXTENT:=144.0
const ORIGIN:=Vector2(-72,-88)
const CELL:=EXTENT/float(N)
var height:=PackedFloat32Array()
var previous:=PackedFloat32Array()
var next:=PackedFloat32Array()
var foam:=PackedFloat32Array()
var solid:=PackedByteArray()
var rgba:=PackedFloat32Array()
var texture:ImageTexture
var accumulator:=0.0
var total_impulses:=0
var last_step_ms:=0.0

func _init()->void:
	height.resize(N*N);previous.resize(N*N);next.resize(N*N);foam.resize(N*N);solid.resize(N*N);rgba.resize(N*N*4)
	texture=ImageTexture.create_from_image(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,rgba.to_byte_array()))

func set_obstacles(boxes:Array,level:float)->void:
	solid.fill(0)
	for b:AABB in boxes:
		if b.position.y>=level-0.03 or b.end.y<level+0.04:continue
		var lo:=Vector2i((Vector2(b.position.x,b.position.z)-ORIGIN)/CELL)
		var hi:=Vector2i((Vector2(b.end.x,b.end.z)-ORIGIN)/CELL)
		for z in range(maxi(1,lo.y),mini(N-1,hi.y+1)):
			for x in range(maxi(1,lo.x),mini(N-1,hi.x+1)):
				var i:=z*N+x;solid[i]=1;height[i]=0;previous[i]=0;foam[i]=0

func disturb(pos:Vector3,radius:float,power:float,white:float=0.0)->void:
	var p:Vector2=(Vector2(pos.x,pos.z)-ORIGIN)/CELL
	var r:float=maxf(1.3,radius/CELL)
	for z in range(maxi(1,int(p.y-r-1)),mini(N-1,int(p.y+r+2))):
		for x in range(maxi(1,int(p.x-r-1)),mini(N-1,int(p.x+r+2))):
			var d:float=Vector2(x-p.x,z-p.y).length()/r
			if d>=1:continue
			var i:=z*N+x
			if solid[i]>0:continue
			var w:float=(1-d*d)*(1-d*d)
			height[i]=clampf(height[i]+w*power,-0.5,0.5)
			foam[i]=minf(1.0,foam[i]+w*white)
	total_impulses+=1

func update(dt:float)->void:
	accumulator+=dt
	if accumulator<1.0/30.0:return
	accumulator=fmod(accumulator,1.0/30.0)
	var started:=Time.get_ticks_usec()
	for z in range(1,N-1):
		for x in range(1,N-1):
			var i:=z*N+x
			if solid[i]>0:next[i]=0;continue
			var h:float=height[i]
			var a:float=height[i-1] if solid[i-1]==0 else h
			var b:float=height[i+1] if solid[i+1]==0 else h
			var c:float=height[i-N] if solid[i-N]==0 else h
			var d:float=height[i+N] if solid[i+N]==0 else h
			next[i]=clampf((2*h-previous[i]+0.22*(a+b+c+d-4*h))*0.989,-0.6,0.6)
			foam[i]=maxf(0,foam[i]*0.973-0.001)
	var old:=previous;previous=height;height=next;next=old
	for i in N*N:
		rgba[i*4]=height[i];rgba[i*4+1]=(height[i]-previous[i])*30.0;rgba[i*4+2]=foam[i];rgba[i*4+3]=float(solid[i])
	texture.update(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,rgba.to_byte_array()))
	last_step_ms=float(Time.get_ticks_usec()-started)/1000.0

func energy()->float:
	var sum:=0.0
	for h in height:sum+=h*h
	return sum
