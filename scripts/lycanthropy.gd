extends Node
var game: Node3D
var infected_wave := -1
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
void fragment(){ vec3 c=textureLod(screen_texture,SCREEN_UV,blur).rgb; c=mix(c,c*vec3(1.35,.55,.48),red); COLOR=vec4(c,1.0); }
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	overlay.material = material
	canvas.add_child(overlay)
func infect() -> void:
	if infected_wave>=0: return
	infected_wave = game.level
	game.show_notice("The werewolf's bite burns. LYCANTHROPY — five rounds of worsening vision.",8)
func transformed() -> bool:
	return infected_wave>=0 and game.level>=infected_wave+5 and game.level%5==0
func maximum_health() -> float: return 200.0 if transformed() else 100.0
func blur_amount() -> float:
	if infected_wave<0 or game.level>=infected_wave+5: return 0.0
	return .7+float(maxi(0,game.level-infected_wave))*.55
func _process(_delta: float) -> void:
	game.player.supernatural_speed = 1.5 if transformed() else 1.0
	overlay.visible = game.mode in ["playing","paused","shop"] and (blur_amount()>0 or transformed())
	overlay.material.set_shader_parameter("blur",blur_amount())
	overlay.material.set_shader_parameter("red",.65 if transformed() else 0.0)
