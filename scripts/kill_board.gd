extends Control
## Host-owned kill ledger; compact summaries plus a short, non-blocking kill feed.
var game: Node
var rows: Dictionary={}
var feed: Array=[]
var expanded:=false
var revision:=0
var seen_revision:=-1
var redraw_left:=0.0
var font:=ThemeDB.fallback_font
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func clear() -> void:
	rows.clear(); feed.clear(); revision=0; seen_revision=-1
func mark(animal: Node,weapon: String,peer: int=-1) -> void:
	animal.set_meta("kill_peer",game.coop.shooter if peer<0 else peer)
	animal.set_meta("kill_weapon",weapon); animal.set_meta("kill_organs",[])
func killed(animal: Node,reward: int) -> void:
	if game.coop.client() or animal.get_meta("kill_recorded",false): return
	animal.set_meta("kill_recorded",true)
	finish.call_deferred(animal,reward)
func finish(animal: Node,reward: int) -> void:
	if not is_instance_valid(animal): return
	var peer:int=animal.get_meta("kill_peer",game.coop.shooter)
	if peer<=0: return
	var slot:=1 if peer==1 else int(game.coop.slots.get(peer,1))+1
	var species:String=("werewolf" if animal.werewolf else "wolf") if animal is IslandWolf else str(animal.species)
	if not rows.has(slot): rows[slot]={"total":0,"credits":0,"species":{}}
	var row:Dictionary=rows[slot]; row.total+=1; row.credits+=game.coop.reward_amount(reward,peer)
	row.species[species]=int(row.species.get(species,0))+1
	var organs:Array=animal.get_meta("kill_organs",[])
	var event:Dictionary={"slot":slot,"species":species,"weapon":str(animal.get_meta("kill_weapon","BLEED / ENVIRONMENT")),"vital":"heart" if organs.has("heart") else "head" if organs.has("brain") or organs.has("head") else "","remaining":4.0}
	revision+=1; receive(rows,event,revision)
	if game.coop.active: game.coop.send_all("kill_update",[rows,event,revision])
func receive(data: Dictionary,event: Dictionary,serial: int) -> void:
	if serial<=seen_revision: return
	seen_revision=serial; rows=data.duplicate(true); feed.push_front(event.duplicate(true))
	while feed.size()>2: feed.pop_back()
	queue_redraw()
func _process(delta: float) -> void:
	for event in feed: event.remaining-=delta
	feed=feed.filter(func(event):return event.remaining>0)
	redraw_left-=delta
	if redraw_left<=0: redraw_left=.1; queue_redraw()
func _input(event: InputEvent) -> void:
	if game.mode not in ["playing","waiting"]: return
	if event is InputEventKey and event.pressed and not event.echo and game.controller_device<0 and event.physical_keycode==KEY_K: expanded=not expanded; queue_redraw()
	if event is InputEventJoypadButton and event.pressed and event.device==game.controller_device and event.button_index==JOY_BUTTON_BACK: expanded=not expanded; queue_redraw()
func details(extent: Vector2) -> void:
	var ids:Array=rows.keys(); ids.sort()
	var x:=extent.x*.5-440; var y:=12.0
	var count:=0
	for id in ids: count+=ceili(rows[id].species.size()/6.0)+1
	draw_rect(Rect2(x,y,880,42+count*18),Color(.02,.03,.04,.96))
	draw_string(font,Vector2(x+12,y+22),"HUNT LEDGER / K or controller View to close",HORIZONTAL_ALIGNMENT_LEFT,856,15)
	y+=43
	for id in ids:
		var row:Dictionary=rows[id]
		draw_string(font,Vector2(x+12,y),"P%d · %d kills · %d CR value"%[id,row.total,row.credits],HORIZONTAL_ALIGNMENT_LEFT,856,14,Color("e4b891")); y+=18
		var species:Array=row.species.keys(); species.sort()
		for i in species.size():
			var p:=Vector2(x+20+(i%6)*140,y)
			preload("res://scripts/radar_icons.gd").species_icon(self,str(species[i]),p-Vector2(0,4),Color("d6c7ac"))
			draw_string(font,p+Vector2(12,0),"%s ×%d"%[str(species[i]).capitalize(),row.species[species[i]]],HORIZONTAL_ALIGNMENT_LEFT,120,11)
			if i%6==5 or i==species.size()-1: y+=18
func _draw() -> void:
	if game.mode not in ["playing","waiting","paused","resting"]: return
	var screen:=get_viewport_rect().size
	var factor:=clampf(screen.x/1280.0,.55,1.0)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	var extent:=screen/factor
	var width:=minf(380,extent.x*.35)
	if expanded:
		details(extent)
		return
	var top:=maxf(110,extent.y*.19)
	for i in feed.size():
		var event:Dictionary=feed[i]; var at:=Vector2((extent.x-width)*.5,top+i*42)
		draw_rect(Rect2(at,Vector2(width,38)),Color(.06,.035,.035,.88))
		preload("res://scripts/radar_icons.gd").species_icon(self,event.species,at+Vector2(15,19),Color("e4b891"))
		if event.vital=="heart":
			var p:=at+Vector2(width-17,17)
			draw_circle(p+Vector2(-3,-2),4,Color("ff6464")); draw_circle(p+Vector2(3,-2),4,Color("ff6464"))
			draw_colored_polygon(PackedVector2Array([p+Vector2(-7,0),p+Vector2(7,0),p+Vector2(0,8)]),Color("ff6464"))
		elif event.vital=="head": preload("res://scripts/radar_icons.gd").skull(self,at+Vector2(width-17,18),Color("ff6464"))
		draw_string(font,at+Vector2(30,15),"P%d  /  %s"%[event.slot,event.species.to_upper()],HORIZONTAL_ALIGNMENT_LEFT,width-60,12,Color("ffe0ba"))
		draw_string(font,at+Vector2(30,30),event.weapon,HORIZONTAL_ALIGNMENT_LEFT,width-60,10,Color("c5d0d3"))
