extends Node2D

# Quete "Ampoule" : le brouillard tombe et 4 lanternes eteintes sont cachees
# dans l'arene. Rester un moment a cote d'une lanterne l'allume.
# Il faut les allumer dans un ordre secret :
# - bonne lanterne  -> cercle vert, elle reste allumee (et eclaire) ;
# - mauvaise        -> cercle rouge, toutes les lanternes se rallument... eteintes.
# Les 4 allumees dans l'ordre -> le brouillard se leve, quete reussie.
# Fin de manche avant -> quete ratee (le brouillard se leve aussi).

signal completed(quest_id)

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")
const PapFog = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_fog.gd")

const LANTERN_TEXTURE = preload("res://dlcs/dlc_1/items/lantern/lantern_icon.png")
const GOOD_SOUND = preload("res://items/consumables/meca_parts/get_meca_part.wav")
const BAD_SOUND = preload("res://entities/units/enemies/crash_zone/basic/pursuer/sci-fi_code_fail_08.wav")

const LANTERN_SIZE = 64.0
const FLASH_TIME = 0.8
const GOOD_COLOR = Color(0.3, 1.0, 0.4, 1.0)
const BAD_COLOR = Color(1.0, 0.25, 0.25, 1.0)
const PROGRESS_COLOR = Color(1.0, 0.9, 0.5, 1.0)

var quest_id: String = PapUtils.QUEST_LANTERNS
var main = null

var _lanterns: = []     # Node2D (une par lanterne)
var _ranks: = []        # ordre secret de chaque lanterne (0 = premiere)
var _lit: = []
var _progress: = []     # temps passe a cote (s)
var _armed: = []        # false apres une erreur, tant qu'un joueur reste a cote
var _flashes: = []      # [[position, couleur, temps restant], ...]
var _next_rank: = 0
var _done: = false
var _elapsed: = 0.0
var _fog = null
var _overlay: Node2D = null
var _hud: CanvasLayer = null
var _hud_label: Label = null

const HUD_FONT = preload("res://resources/fonts/actual/base/font_26_outline.tres")
const HUD_Y = 175.0


func _refresh_hud() -> void :
	if _hud_label != null:
		_hud_label.text = tr("TINKILUZ_PAP_LANTERNS_LIT").format([_next_rank, _lanterns.size()])


func _exit_tree() -> void :
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()


func _ready() -> void :
	_fog = PapFog.new()
	_fog.name = "TinkiluzPapFog"
	_fog.main = main
	main.add_child(_fog)

	var avoid: = []
	if main.tinkiluz_machine != null and is_instance_valid(main.tinkiluz_machine):
		avoid.push_back(main.tinkiluz_machine.global_position)

	var count: int = PapUtils.get_lantern_count(main.tinkiluz_wave_duration)
	var order: = range(count)
	order.shuffle()

	for i in count:
		var lantern: = Node2D.new()
		lantern.global_position = main.tinkiluz_get_random_position(PapUtils.LANTERN_MIN_DISTANCE_FROM_EDGE, avoid, PapUtils.LANTERN_MIN_DISTANCE)
		avoid.push_back(lantern.global_position)
		add_child(lantern)
		_lanterns.push_back(lantern)
		_ranks.push_back(order[i])
		_lit.push_back(false)
		_progress.push_back(0.0)
		_armed.push_back(true)

	# Compteur en haut de l'ecran (sous le minuteur de la manche)
	_hud = CanvasLayer.new()
	_hud.name = "TinkiluzPapLanternsHud"
	main.add_child(_hud)
	_hud_label = Label.new()
	_hud_label.add_font_override("font", HUD_FONT)
	_hud_label.align = Label.ALIGN_CENTER
	_hud_label.anchor_left = 0.0
	_hud_label.anchor_right = 1.0
	_hud_label.margin_top = HUD_Y
	_hud.add_child(_hud_label)
	_refresh_hud()

	# Cercles et jauges au-dessus du brouillard
	_overlay = Overlay.new()
	_overlay.quest = self
	_overlay.z_index = 2
	_overlay.z_as_relative = false
	add_child(_overlay)


func _physics_process(delta: float) -> void :
	_elapsed += delta

	for flash in _flashes:
		flash[2] -= delta
	for i in range(_flashes.size() - 1, - 1, - 1):
		if _flashes[i][2] <= 0.0:
			_flashes.remove(i)

	if not _done:
		for i in _lanterns.size():
			_update_lantern(i, delta)

	update()
	_overlay.update()


func _update_lantern(i: int, delta: float) -> void :
	if _lit[i]:
		return
	var near: bool = _is_player_near(_lanterns[i].global_position)

	# Apres une erreur, il faut s'eloigner avant de pouvoir reessayer
	if not _armed[i]:
		if not near:
			_armed[i] = true
		return

	if not near:
		_progress[i] = max(0.0, _progress[i] - delta * 2.0)
		return

	_progress[i] += delta
	if _progress[i] >= PapUtils.LANTERN_LIGHT_TIME:
		_progress[i] = 0.0
		_activate(i)


func _activate(i: int) -> void :
	var pos: Vector2 = _lanterns[i].global_position

	if _ranks[i] == _next_rank:
		_lit[i] = true
		_next_rank += 1
		_fog.add_light(_lanterns[i], PapUtils.LANTERN_LIGHT_SCALE)
		_flashes.push_back([pos, GOOD_COLOR, FLASH_TIME])
		SoundManager2D.play(GOOD_SOUND, pos, 0, 0.1)
		_refresh_hud()
		if _next_rank >= _lanterns.size():
			_complete()
		return

	# Mauvais ordre : tout s'eteint
	_flashes.push_back([pos, BAD_COLOR, FLASH_TIME])
	for j in _lanterns.size():
		if _lit[j]:
			_lit[j] = false
			_fog.remove_light(_lanterns[j])
			_flashes.push_back([_lanterns[j].global_position, BAD_COLOR, FLASH_TIME])
	_next_rank = 0
	_refresh_hud()
	_armed[i] = false
	SoundManager2D.play(BAD_SOUND, pos, 0, 0.1)


func _is_player_near(pos: Vector2) -> bool:
	for player in main._players:
		if player != null and is_instance_valid(player) and not player.dead:
			if player.global_position.distance_to(pos) <= PapUtils.LANTERN_RADIUS:
				return true
	return false


func _complete() -> void :
	_done = true
	emit_signal("completed", quest_id)
	remove()


# Fin de la quete (reussie ou ratee) : le brouillard se leve, les lanternes partent
func remove() -> void :
	_done = true
	if _fog != null and is_instance_valid(_fog):
		_fog.lift()
	var timer: = get_tree().create_timer(FLASH_TIME, false)
	timer.connect("timeout", self, "queue_free")


# --- Dessin ------------------------------------------------------------------------

# Lanternes (sous le brouillard : on ne les voit que de pres ou allumees)
func _draw() -> void :
	for i in _lanterns.size():
		var pos: Vector2 = _lanterns[i].position
		var size: = Vector2(LANTERN_SIZE, LANTERN_SIZE)
		var bob: float = sin(_elapsed * 2.0 + i) * 2.0 if _lit[i] else 0.0
		var rect: = Rect2(pos - size / 2.0 + Vector2(0, bob), size)
		draw_circle(pos + Vector2(0, size.y / 2.0 - 4.0), 18.0, Color(0, 0, 0, 0.3))
		var tint: Color = Color.white if _lit[i] else Color(0.35, 0.35, 0.4, 1.0)
		draw_texture_rect(LANTERN_TEXTURE, rect, false, tint)


# Au-dessus du brouillard : jauge d'allumage, cercles vert/rouge.
# Aucun indice sur l'ordre : il se trouve en essayant.
func draw_overlay(ci: CanvasItem) -> void :
	for i in _lanterns.size():
		var pos: Vector2 = _lanterns[i].position
		if not _lit[i] and _progress[i] > 0.0:
			var ratio: float = clamp(_progress[i] / PapUtils.LANTERN_LIGHT_TIME, 0.0, 1.0)
			ci.draw_arc(pos, PapUtils.LANTERN_RADIUS * 0.6, - PI / 2.0, - PI / 2.0 + TAU * ratio, 32, PROGRESS_COLOR, 4.0, true)

	for flash in _flashes:
		var t: float = 1.0 - flash[2] / FLASH_TIME
		var color: Color = flash[1]
		color.a = 1.0 - t
		var radius: float = PapUtils.LANTERN_RADIUS * (0.6 + 0.6 * t)
		var local_pos: Vector2 = flash[0] - global_position
		var fill: = color
		fill.a *= 0.25
		ci.draw_circle(local_pos, radius, fill)
		ci.draw_arc(local_pos, radius, 0.0, TAU, 48, color, 5.0, true)


class Overlay extends Node2D:
	var quest = null

	func _draw() -> void :
		if quest != null:
			quest.draw_overlay(self)
