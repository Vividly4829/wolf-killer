extends Control
## Original field-manual silhouette: body regions reflect the real injury values.
var game: Node
var font:=ThemeDB.fallback_font
const OK:=Color("bcdaa2")
const HURT:=Color("ff735d")
func _ready() -> void:
	size=Vector2(244,158); mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	visible=game.mode=="playing"; queue_redraw()
func region(value: float) -> Color: return HURT if value>0 else OK
func line(a: Vector2,b: Vector2,color: Color,width: float=9) -> void:
	draw_line(a,b,color,width,true); draw_circle(a,width*.5,color); draw_circle(b,width*.5,color)
func status_lines() -> Array[String]:
	var result: Array[String]=[]
	var p=game.player
	if p.bleeding_rate>0: result.append("BLEEDING")
	if p.leg_injury>0: result.append("LEG INJURY")
	if p.arm_injury>0: result.append("ARM INJURY")
	if p.concussion>0: result.append("CONCUSSION")
	if game.campaign.fever: result.append("FEVER")
	if game.affliction.infected_wave>=0: result.append("LYCANTHROPY")
	if result.is_empty(): result.append("HEALTHY")
	return result
func _draw() -> void:
	if not is_instance_valid(game.player): return
	draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.055,.045,.88))
	draw_rect(Rect2(Vector2.ZERO,size),Color("63705a"),false,1)
	draw_string(font,Vector2(12,18),"FIELD CONDITION",HORIZONTAL_ALIGNMENT_LEFT,220,11,OK)
	var p=game.player
	draw_circle(Vector2(51,44),12,region(p.concussion))
	draw_line(Vector2(35,34),Vector2(68,34),OK,4,true)
	draw_line(Vector2(42,28),Vector2(60,28),OK,7,true)
	line(Vector2(51,62),Vector2(51,98),region(p.bleeding_rate),23)
	for side in [-1,1]:
		line(Vector2(51+side*16,63),Vector2(51+side*23,85),region(p.arm_injury),8)
		line(Vector2(51+side*23,85),Vector2(51+side*28,102),region(p.arm_injury),7)
		line(Vector2(51+side*9,101),Vector2(51+side*12,121),region(p.leg_injury),10)
		line(Vector2(51+side*12,121),Vector2(51+side*15,140),region(p.leg_injury),9)
		if p.leg_injury>0: draw_polyline(PackedVector2Array([Vector2(51+side*9,114),Vector2(51+side*16,119),Vector2(51+side*9,124)]),Color("1b251f"),2,true)
	if p.bleeding_rate>0:
		draw_colored_polygon(PackedVector2Array([Vector2(51,70),Vector2(44,84),Vector2(58,84)]),Color("801f2e"))
	var labels:=status_lines()
	for i in labels.size(): draw_string(font,Vector2(92,42+i*18),labels[i],HORIZONTAL_ALIGNMENT_LEFT,147,11,OK if labels[i]=="HEALTHY" else HURT)
