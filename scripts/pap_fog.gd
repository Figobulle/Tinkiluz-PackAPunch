extends Node

# Brouillard pour les quetes, copie du systeme du jeu (visual_effects/fog_viewport.gd) :
# un Viewport noir dans lequel on dessine des lumieres (scenes du jeu), affiche
# par-dessus l'arene avec un Sprite en mode "multiplier".
#
# Le brouillard du jeu est supprime au debut de la manche s'il ne sert pas, on
# ne peut donc pas l'allumer en cours de manche : on cree le notre.
# Si la manche a deja le brouillard du jeu (homme des cavernes, evenement),
# on ne cree rien et on ajoute nos lumieres dans celui du jeu.

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")
const PLAYER_LIGHT_SCENE = preload("res://visual_effects/player_light_in_shadow.tscn")
const OBJECT_LIGHT_SCENE = preload("res://visual_effects/structure_and_pet_light_in_shadow.tscn")

const FADE_TIME = 1.0

var main = null

var _uses_game_fog: = false
var _viewport: Viewport = null
var _sprite: Sprite = null
var _wave_fog_scale: = 1.0
var _base_fog_scale: = Vector2.ONE
var _player_lights: = []        # [light, player_index]
var _object_lights: = {}        # node suivi -> light
var _alpha: = 0.0
var _fading_out: = false


func _ready() -> void :
	_uses_game_fog = main._is_fog_wave and is_instance_valid(main._fog_viewport)
	if _uses_game_fog:
		return

	_viewport = Viewport.new()
	_viewport.name = "TinkiluzPapFogViewport"
	_viewport.size = Vector2(1920, 1080)
	_viewport.hdr = false
	_viewport.disable_3d = true
	_viewport.usage = Viewport.USAGE_2D
	_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	add_child(_viewport)

	var black: = ColorRect.new()
	black.rect_size = Vector2(3840, 2160)
	black.color = Color(0, 0, 0, 1)
	_viewport.add_child(black)

	var material: = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_sprite = Sprite.new()
	_sprite.name = "TinkiluzPapFog"
	_sprite.material = material
	_sprite.texture = _viewport.get_texture()
	_sprite.flip_v = true
	_sprite.centered = true
	_sprite.z_index = 1
	_sprite.modulate.a = 0.0
	add_child(_sprite)

	_base_fog_scale = main.get_viewport().get_visible_rect().size / _viewport.size

	# Meme echelle que le brouillard du jeu (plus grande au debut du run). Elle
	# sert aussi a couvrir tout l'ecran : on ne la reduit pas, on reduit les
	# lumieres (FOG_VISIBILITY).
	var wave: float = min(RunData.current_wave, 20)
	_wave_fog_scale = 2.75 - 1.75 * (wave / 20.0)

	for player_index in RunData.get_player_count():
		var light = PLAYER_LIGHT_SCENE.instance()
		_viewport.add_child(light)
		var bonus: float = clamp(RunData.get_player_effect(Keys.stat_fog_visibility_hash, player_index), - 100.0, 9999.0) / 100.0
		_player_lights.push_back([light, player_index, max(0.1, 1.0 + bonus) * PapUtils.FOG_VISIBILITY])


# Lumiere qui suit un noeud de l'arene (lanterne allumee...)
func add_light(node: Node2D, light_scale: float) -> void :
	if _object_lights.has(node):
		return
	var parent: Node = main._fog_viewport if _uses_game_fog else _viewport
	if parent == null or not is_instance_valid(parent):
		return
	var light = OBJECT_LIGHT_SCENE.instance()
	light.set_meta("tinkiluz_scale", light_scale)
	parent.add_child(light)
	_object_lights[node] = light


func remove_light(node: Node2D) -> void :
	if not _object_lights.has(node):
		return
	var light = _object_lights[node]
	_object_lights.erase(node)
	if is_instance_valid(light):
		light.queue_free()


# Le brouillard se leve puis le noeud disparait
func lift() -> void :
	_fading_out = true


func _exit_tree() -> void :
	# Lumieres ajoutees dans le brouillard du jeu : on les retire
	for node in _object_lights.keys():
		remove_light(node)


func _process(delta: float) -> void :
	var camera = main._camera

	if _fading_out:
		_alpha = max(0.0, _alpha - delta / FADE_TIME)
		if _alpha <= 0.0:
			queue_free()
			return
	else:
		_alpha = min(1.0, _alpha + delta / FADE_TIME)

	var scale_factor: float
	var view_size: Vector2
	var camera_pos: Vector2 = camera.global_position

	if _uses_game_fog:
		var game_fog: Sprite = main._fog_viewport.fog_sprite
		if not is_instance_valid(game_fog):
			return
		scale_factor = game_fog.scale.x
		view_size = main._fog_viewport.size
	else:
		_sprite.modulate.a = _alpha
		_sprite.scale = _base_fog_scale * _wave_fog_scale * camera.zoom.x
		_sprite.global_position = camera_pos
		scale_factor = _sprite.scale.x
		view_size = _viewport.size

		for entry in _player_lights:
			var light = entry[0]
			var player = main._players[entry[1]] if entry[1] < main._players.size() else null
			if player == null or not is_instance_valid(player) or player.dead:
				light.visible = false
				continue
			light.visible = true
			light.scale = Vector2.ONE * entry[2] / camera.zoom.x
			light.global_position = (player.global_position - camera_pos) / scale_factor + view_size / 2.0

	for node in _object_lights.keys():
		var light = _object_lights[node]
		if not is_instance_valid(node):
			remove_light(node)
			continue
		var visibility: float = 1.0 if _uses_game_fog else PapUtils.FOG_VISIBILITY
		light.scale = Vector2.ONE * light.get_meta("tinkiluz_scale") * visibility / camera.zoom.x
		light.global_position = (node.global_position - camera_pos) / scale_factor + view_size / 2.0
