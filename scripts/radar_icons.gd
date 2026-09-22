extends RefCounted

static func icon(canvas: Control,animal: Node3D,p: Vector2,c: Color) -> void:
	var species: String = "werewolf" if animal.get("werewolf") == true else ("wolf" if animal is IslandWolf else str(animal.get("species")))
	canvas.draw_circle(p,8,Color(.025,.045,.06,.85))
	if species in ["duck","goose"]:
		ellipse(canvas,p+Vector2(-1,2),Vector2(5,3),c)
		var head := p+Vector2(4,-5 if species == "goose" else -2)
		canvas.draw_line(p+Vector2(3,2),head,c,2); canvas.draw_circle(head,2,c); canvas.draw_line(head,head+Vector2(4,0),c,2)
	elif species == "deer":
		canvas.draw_circle(p+Vector2(0,2),3,c)
		for side in [-1,1]:
			canvas.draw_line(p,p+Vector2(side*5,-6),c,1.5)
			canvas.draw_line(p+Vector2(side*3,-3),p+Vector2(side*6,-3),c,1.5)
	elif species in ["wolf","werewolf","bear"]:
		canvas.draw_circle(p+Vector2(0,1),4,c)
		for side in [-1,1]:
			if species == "bear": canvas.draw_circle(p+Vector2(side*4,-3),2.5,c)
			else: canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(side*2,-2),p+Vector2(side*5,-6),p+Vector2(side*5,1)]),c)
		canvas.draw_circle(p+Vector2(0,3),1.5,Color("19212a"))
		if species == "werewolf": canvas.draw_line(p+Vector2(-6,6),p+Vector2(6,6),c,2)
	elif species == "mink":
		ellipse(canvas,p,Vector2(5,2),c); canvas.draw_line(p+Vector2(-4,0),p+Vector2(-7,-4),c,2); canvas.draw_circle(p+Vector2(5,-1),2,c)
	else:
		canvas.draw_circle(p+Vector2(0,-4),2.5,c); canvas.draw_line(p,p+Vector2(0,5),c,3); canvas.draw_line(p+Vector2(-4,1),p+Vector2(4,1),c,2)
static func ellipse(canvas: Control,p: Vector2,r: Vector2,c: Color) -> void:
	var points := PackedVector2Array()
	for i in 12: points.append(p+Vector2(cos(i*TAU/12),sin(i*TAU/12))*r)
	canvas.draw_colored_polygon(points,c)

static func skull(canvas: Control,p: Vector2,c: Color) -> void:
	canvas.draw_circle(p,4.5,Color("162129"))
	canvas.draw_circle(p+Vector2(0,-1),3.5,c)
	canvas.draw_rect(Rect2(p+Vector2(-2,1),Vector2(4,3)),c)
	for side in [-1,1]: canvas.draw_circle(p+Vector2(side*1.5,-1),1,Color("162129"))
	canvas.draw_line(p+Vector2(0,2),p+Vector2(0,4),Color("162129"),1)
