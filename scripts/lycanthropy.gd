extends Node
var game: Node3D
var infected_wave := -1
var psychedelic := false
var overlay: ColorRect
func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur = 0.0;
uniform float red = 0.0;
uniform float vivid = 0.0;
void fragment(){ vec3 c=textureLod(screen_texture,SCREEN_UV,blur).rgb; c=mix(c,c*vec3(1.35,.55,.48),red); float l=dot(c,vec3(.2126,.7152,.0722)); c=mix(c,mix(vec3(l),c,2.4)*1.18,vivid); COLOR=vec4(c,1.0); }
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	overlay.material = material
	canvas.add_child(overlay)
func infect() -> void:
	if infected_wave>=0: return
	infected_wave = game.level
	game.player.supernatural_speed = 1.5
	game.show_notice("LYCANTHROPY — faster, red vision. Survive the next werewolf round to keep 200 HP.",8)
func transformed() -> bool: return infected_wave >= 0
func empowered() -> bool:
	return infected_wave >= 0 and game.level > (floori(infected_wave / 5.0) + 1) * 5
func maximum_health() -> float:
	return (200.0 if empowered() else 100.0) * (.7 if psychedelic else 1.0) * (game.rituals.factor("health") if game.rituals else 1.0)
func blur_amount() -> float: return 0.0
func consume() -> void:
	psychedelic = true
	game.health = minf(game.health,maximum_health())
	game.show_notice("PSYCHEDELIC — vivid colours, all-animal radar, -30% maximum HP until you rest.",7)
func _process(_delta: float) -> void:
	game.player.supernatural_speed = 1.5 if transformed() else 1.0
	overlay.visible = game.mode in ["playing","paused","shop"] and (psychedelic or transformed())
	overlay.material.set_shader_parameter("blur",0.0)
	overlay.material.set_shader_parameter("red",.4 if transformed() else 0.0)
	overlay.material.set_shader_parameter("vivid",1.0 if psychedelic else 0.0)
