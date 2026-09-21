extends Control
var game: Node
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if game.mode not in ["playing","waiting","dead"]: return
	var impact: float=game.damage_flash
	var bleeding: float=game.player.bleeding_rate
	if impact<=0 and bleeding<=0: return
	var alpha:=clampf(impact*.18+bleeding*.025,0,.38)
	var edge:=Color(.32,.015,.015,alpha)
	for i in 12:
		var pad:=float(i)*5
		draw_rect(Rect2(Vector2.ONE*pad,size-Vector2.ONE*pad*2),Color(edge,edge.a*(1-i/12.0)),false,6)
	for i in 17:
		var x:=fmod(i*177.1+51,size.x)
		var y:=fmod(i*117.7+21,size.y)
		if x>size.x*.25 and x<size.x*.75 and y>size.y*.2 and y<size.y*.8: continue
		draw_circle(Vector2(x,y),3+(i%4)*2,Color(.35,.015,.015,clampf(impact*.35,0,.7)))
