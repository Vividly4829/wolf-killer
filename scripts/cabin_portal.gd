extends RefCounted
## Runtime game-only doorway cut. Original architectural assets stay byte-identical.
const CENTER := Vector3(-3.5,4.9,-.64)
const EXTENTS := Vector3(.65,1.10,.55)
static func portal_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,.2),CENTER)
static func cut(mesh: Mesh,world: Transform3D, portal: Transform3D = Transform3D.IDENTITY, extent: Vector3 = EXTENTS) -> Mesh:
	if portal==Transform3D.IDENTITY: portal = portal_transform()
	var transform := portal.affine_inverse()*world
	var bounds: AABB = transform*mesh.get_aabb()
	if not bounds.intersects(AABB(-extent,extent*2)): return mesh
	var output := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := indices.size() if not indices.is_empty() else verts.size()
		for tri in range(0,count,3):
			var polygon: Array = []
			for k in 3:
				var i: int = indices[tri+k] if not indices.is_empty() else tri+k
				polygon.append({"p":verts[i],"q":transform*verts[i],"n":normals[i],"c":colors[i] if not colors.is_empty() else Color.WHITE})
			var remaining := polygon
			for axis in 3:
				for sign_value in [-1.0,1.0]:
					var outside := clip(remaining,axis,sign_value,false,extent)
					for k in range(1,outside.size()-1):
						for v: Dictionary in [outside[0],outside[k],outside[k+1]]:
							st.set_color(v.c)
							st.set_normal(v.n)
							st.add_vertex(v.p)
					remaining = clip(remaining,axis,sign_value,true,extent)
		st.commit(output)
	return output
static func clip(poly: Array,axis: int,sign_value: float,inside: bool,extent: Vector3 = EXTENTS) -> Array:
	var out: Array = []
	if poly.is_empty(): return out
	for i in poly.size():
		var a: Dictionary = poly[i]
		var b: Dictionary = poly[(i+1)%poly.size()]
		var da: float = a.q[axis]*sign_value-extent[axis]
		var db: float = b.q[axis]*sign_value-extent[axis]
		var keep_a: bool = da<=0 if inside else da>0
		var keep_b: bool = db<=0 if inside else db>0
		if keep_a: out.append(a)
		if keep_a != keep_b:
			var t := da/(da-db)
			out.append({"p":a.p.lerp(b.p,t),"q":a.q.lerp(b.q,t),"n":a.n.lerp(b.n,t).normalized(),"c":a.c.lerp(b.c,t)})
	return out
static func open_navigation(grid: Dictionary) -> void:
	var inverse := portal_transform().affine_inverse()
	for i in grid.heights.size():
		var x: float = grid.origin[0]+(i%int(grid.width))*float(grid.cellSize)
		var z: float = grid.origin[1]+int(i/int(grid.width))*float(grid.cellSize)
		var p := inverse*Vector3(x,3.85,z)
		if absf(p.x)<.53 and absf(p.z)<1.35:
			grid.blocked[i] = 0
			grid.heights[i] = 3.85
