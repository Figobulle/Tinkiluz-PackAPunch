extends Node2D

# La machine Pack-a-Punch posee dans l'arene (commune a toute l'equipe).
# - Apparait avec la croix de naissance des arbres, puis "respire" comme eux.
# - Eteinte (grise) tant que les composants ne sont pas tous obtenus.
# - Un joueur vivant a cote voit "[touche] Pack-a-Punch" et peut interagir
#   (ui_accept, sa propre manette en coop) -> main.tinkiluz_on_interact().
#
# Cycle d'amelioration (manche d'au moins MIN_WAVE_DURATION) :
#   - pendant le 1er tiers, un joueur depose une arme (jeton consomme, arme
#     desactivee) : l'amelioration demarre tout de suite et dure 1/3 de manche
#     (bordure qui se remplit) ;
#   - ensuite l'arme est prete, son proprietaire vient la recuperer (panel) ;
#   - fin de manche sans l'avoir recuperee : arme perdue.
# La machine disparait des qu'elle ne sert plus a rien pour cette manche.

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")
const PapWeaponAura = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_weapon_aura.gd")

const PAP_SOUND = preload("res://items/consumables/meca_parts/get_meca_part.wav")
const FONT = preload("res://resources/fonts/actual/base/font_26_outline.tres")

# Sprite de la machine. Charge en Image (pas via l'import Godot) pour marcher
# aussi bien depuis mods-unpacked que depuis un zip de mod.
const SPRITE_PATH = "res://mods-unpacked/Tinkiluz-PackAPunch/assets/pap_machine.png"
const SPRITE_SCALE = 0.5        # 212x256 px a l'origine -> ~106x128 px en jeu
const SPRITE_FEET_OFFSET = 20.0 # les pieds sont un peu sous le centre

# Rebond facon arbre : 1 s par cycle, largeur 1 -> 1.15 -> 1, hauteur 1 -> 0.85 -> 1
const BOUNCE_PERIOD = 1.0
const BOUNCE_SQUASH = 0.15

# Bordure de progression (pixels a l'ecran)
const OUTLINE_OFFSET = 3.0
const OUTLINE_WIDTH = 4.0
const OUTLINE_TRACK_COLOR = Color(0.02, 0.10, 0.16, 0.55)

# Ombre au sol (pixels de texture)
const SHADOW_COLOR = Color(0.0, 0.0, 0.0, 0.3)
const SHADOW_RADIUS = Vector2(92.0, 18.0)
const SHADOW_Y = - 10.0

# Lueur derriere la machine (allumee seulement)
const GLOW_COLOR = Color(0.35, 0.95, 1.0, 1.0)
const GLOW_SIZE_FACTOR = 1.55
const GLOW_CENTER_Y = 0.55
const GLOW_ALPHA = 0.4
const GLOW_ALPHA_OPEN = 0.6     # pendant le 1er tiers (on peut deposer une arme)
const GLOW_FALLOFF = 1.6
const GLOW_PULSE = 0.06

const OFF_TINT = Color(0.45, 0.45, 0.5, 1.0)

# Croix d'apparition (meme visuel / timing que la naissance des arbres)
const BIRTH_TEXTURE = preload("res://entities/birth/entity_birth.png")
const BIRTH_BEGIN_SOUND = preload("res://entities/birth/birth_begin_sound.wav")
const BIRTH_END_SOUND = preload("res://entities/birth/birth_end_sound.wav")
const BIRTH_TIME = 1.0
const BIRTH_SCALE = 0.33
const BIRTH_COLOR = Color(0.45, 1.0, 1.0, 1.0)
const BIRTH_FLICKER_ALPHA = 0.25
const BIRTH_INVISIBLE_TIME = 0.1

# Bulle d'interaction
const PROMPT_Y = - 150.0
const PROMPT_ICON_SIZE = 34.0

var main = null  # main.gd

var _texture: Texture = null
var _glow_texture: Texture = null
var _outline: = PoolVector2Array()
var _outline_lengths: = []
var _outline_total: = 0.0

var _birthing: = false
var _birth_rotation: = 0.0
var _birth_alpha: = 1.0
var _birth_flicker_cd: = 0.0
var _birth_invisible: = 0.0

var _active: = false
var _elapsed: = 0.0
var _nearby: = []   # joueurs vivants a portee

# Amelioration en cours (une seule par manche)
var upgrade_player: = - 1
var upgrade_weapon: WeaponData = null
var upgrade_ready: = false
var upgrade_used_this_wave: = false
var _upgrade_start: = 0.0   # temps de manche au depot

var _leaving: = false
var _leave_time: = 0.0
const LEAVE_DURATION = 0.4


var _overlay: Node2D = null


func _ready() -> void :
	visible = false
	_overlay = Overlay.new()
	_overlay.machine = self
	_overlay.z_index = 100
	_overlay.z_as_relative = false
	add_child(_overlay)
	var img: = Image.new()
	if img.load(SPRITE_PATH) == OK:
		var tex: = ImageTexture.new()
		tex.create_from_image(img, Texture.FLAG_FILTER)
		_texture = tex
		_build_outline(img)
	_glow_texture = _build_glow_texture()


func is_active() -> bool:
	return _active


# --- Temps de la manche ------------------------------------------------------------

func get_wave_duration() -> float:
	return main.tinkiluz_wave_duration if main != null else 0.0


func get_elapsed_in_wave() -> float:
	if main == null or main._wave_timer.is_stopped():
		return get_wave_duration()
	return get_wave_duration() - main._wave_timer.time_left


# 1, 2 ou 3 (tiers de la manche)
func get_phase() -> int:
	var duration: float = get_wave_duration()
	if duration <= 0.0:
		return 3
	var ratio: float = get_elapsed_in_wave() / duration
	if ratio < 1.0 / 3.0:
		return 1
	if ratio < 2.0 / 3.0:
		return 2
	return 3


func is_upgrade_possible_this_wave() -> bool:
	return get_upgrade_wave_block_reason() == ""


# Raison (cle de texte) pour laquelle personne ne peut deposer d'arme, ou ""
func get_upgrade_wave_block_reason() -> String:
	if not RunData.is_endless_run and RunData.current_wave >= RunData.nb_of_waves:
		return "TINKILUZ_PAP_LAST_WAVE"
	if get_wave_duration() < PapUtils.MIN_WAVE_DURATION:
		return "TINKILUZ_PAP_SHORT_WAVE"
	if upgrade_player >= 0:
		return "TINKILUZ_PAP_BUSY"
	if upgrade_used_this_wave or get_phase() > 1:
		return "TINKILUZ_PAP_TOO_LATE"
	return ""


# --- Amelioration ------------------------------------------------------------------

func start_upgrade(player_index: int, weapon: WeaponData) -> bool:
	if not RunData.tinkiluz_is_machine_on() or not is_upgrade_possible_this_wave():
		return false
	if RunData.tinkiluz_get_pap_tokens(player_index) < PapUtils.TOKEN_COST:
		return false
	if not PapUtils.is_weapon_eligible(weapon):
		return false
	if not weapon in RunData.get_player_weapons_ref(player_index):
		return false

	RunData.tinkiluz_remove_pap_tokens(PapUtils.TOKEN_COST, player_index)
	upgrade_player = player_index
	upgrade_weapon = weapon
	upgrade_ready = false
	upgrade_used_this_wave = true
	_upgrade_start = get_elapsed_in_wave()
	main.tinkiluz_set_weapon_enabled(player_index, weapon, false)
	SoundManager2D.play(PAP_SOUND, global_position, 0, 0.1)
	ModLoaderLog.info("Pack-a-Punch : %s deposee (joueur %s)" % [weapon.my_id, player_index], "Tinkiluz-PackAPunch")
	return true


func can_take_back(player_index: int) -> bool:
	return upgrade_ready and upgrade_player == player_index


func take_back(player_index: int) -> void :
	if not can_take_back(player_index):
		return
	var weapon: WeaponData = upgrade_weapon
	upgrade_player = - 1
	upgrade_weapon = null
	upgrade_ready = false

	PapUtils.set_pap(weapon, true)
	main.tinkiluz_set_weapon_enabled(player_index, weapon, true)
	main.tinkiluz_tint_pap_weapons()
	SoundManager.play(PAP_SOUND, 0, 0.1, true)
	ModLoaderLog.info("Pack-a-Punch : %s recuperee (joueur %s)" % [weapon.my_id, player_index], "Tinkiluz-PackAPunch")
	leave()


# La machine ne sert plus pour cette manche ?
func is_useless() -> bool:
	if upgrade_player >= 0:
		return false
	# Eteinte : toujours visible (quetes)
	if not RunData.tinkiluz_is_machine_on():
		return false
	# Allumee : elle part seulement quand le moment de deposer une arme est
	# passe (1er tiers fini ou arme deja recuperee). Manche courte : elle reste,
	# le panel dit pourquoi on ne peut pas l'utiliser.
	return get_upgrade_wave_block_reason() == "TINKILUZ_PAP_TOO_LATE"


# Disparition (croix de naissance a l'envers, en plus court)
func leave() -> void :
	if _leaving:
		return
	_leaving = true
	_leave_time = 0.0
	_nearby = []
	SoundManager2D.play(BIRTH_BEGIN_SOUND, global_position, - 5, 0.2)


# Fin de manche : arme pas recuperee = perdue
func on_wave_ended() -> void :
	if upgrade_player >= 0 and upgrade_weapon != null:
		RunData.tinkiluz_remove_exact_weapon(upgrade_weapon, upgrade_player)
		main.tinkiluz_show_text("TINKILUZ_PAP_LOST", global_position + Vector2(0, PROMPT_Y), Color(ProgressData.settings.color_negative))
		ModLoaderLog.info("Pack-a-Punch : %s perdue (joueur %s)" % [upgrade_weapon.my_id, upgrade_player], "Tinkiluz-PackAPunch")
	upgrade_player = - 1
	upgrade_weapon = null
	upgrade_ready = false
	_active = false
	queue_free()


# --- Boucle ------------------------------------------------------------------------

func _physics_process(delta: float) -> void :
	_elapsed += delta

	if _leaving:
		_leave_time += delta
		modulate.a = clamp(1.0 - _leave_time / LEAVE_DURATION, 0.0, 1.0)
		scale = Vector2.ONE * (1.0 - 0.3 * _leave_time / LEAVE_DURATION)
		if _leave_time >= LEAVE_DURATION:
			_active = false
			queue_free()
		return

	if not _active:
		_process_birth(delta)
		return

	if is_useless():
		leave()
		return

	_nearby = _get_nearby_players()

	if upgrade_player >= 0 and not upgrade_ready and _get_upgrade_ratio() >= 1.0:
		upgrade_ready = true
		SoundManager2D.play(PAP_SOUND, global_position, 0, 0.1)
		main.tinkiluz_show_text("TINKILUZ_PAP_READY", global_position + Vector2(0, PROMPT_Y), PapUtils.get_player_color(upgrade_player))

	update()


func _unhandled_input(event: InputEvent) -> void :
	if not _active or _leaving or main == null or main._cleaning_up or get_tree().paused:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	for player_index in _nearby:
		if Utils.is_player_action_pressed(event, player_index, "ui_accept"):
			get_tree().set_input_as_handled()
			main.tinkiluz_on_interact(player_index)
			return


func _get_nearby_players() -> Array:
	var result: = []
	if main == null or not is_instance_valid(main) or main._cleaning_up:
		return result
	for player in main._players:
		if player == null or not is_instance_valid(player) or player.dead:
			continue
		if player.global_position.distance_to(global_position) <= PapUtils.INTERACT_RADIUS:
			result.push_back(player.player_index)
	return result


# --- Apparition --------------------------------------------------------------------

func _process_birth(delta: float) -> void :
	var birth_start: float = max(0.0, PapUtils.SPAWN_DELAY - BIRTH_TIME)
	if _elapsed < birth_start:
		return

	if not _birthing:
		_birthing = true
		visible = true
		_birth_rotation = rand_range(0.0, TAU)
		_birth_alpha = 1.0
		_birth_flicker_cd = _get_birth_remaining() / 3.25
		SoundManager2D.play(BIRTH_BEGIN_SOUND, global_position, 0, 0.2)

	if _birth_alpha <= BIRTH_FLICKER_ALPHA:
		_birth_invisible -= delta
		if _birth_invisible <= 0.0:
			_birth_alpha = 1.0
			_birth_flicker_cd = _get_birth_remaining() / 3.25
	else:
		_birth_flicker_cd -= delta
		if _birth_flicker_cd <= 0.0:
			_birth_alpha = BIRTH_FLICKER_ALPHA
			_birth_invisible = BIRTH_INVISIBLE_TIME

	if _elapsed >= PapUtils.SPAWN_DELAY:
		_birthing = false
		_active = true
		SoundManager2D.play(BIRTH_END_SOUND, global_position, - 15, 0.2)

	update()


func _get_birth_remaining() -> float:
	return max(0.0, PapUtils.SPAWN_DELAY - _elapsed)


# --- Dessin ------------------------------------------------------------------------

func _build_glow_texture() -> Texture:
	var size: = 64
	var center: = Vector2(size / 2.0 - 0.5, size / 2.0 - 0.5)
	var img: = Image.new()
	img.create(size, size, false, Image.FORMAT_RGBA8)
	img.lock()
	for x in size:
		for y in size:
			var d: float = Vector2(x, y).distance_to(center) / (size / 2.0)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(a, GLOW_FALLOFF)))
	img.unlock()
	var tex: = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	return tex


# Contour de la silhouette, decale vers l'exterieur, qui part du haut au centre
func _build_outline(img: Image) -> void :
	var bitmap: = BitMap.new()
	bitmap.create_from_image_alpha(img, 0.5)
	var polygons: Array = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, img.get_size()), 2.0)

	var shape: = PoolVector2Array()
	for polygon in polygons:
		if polygon.size() > shape.size():
			shape = polygon
	if shape.size() < 3:
		return

	var grown: Array = Geometry.offset_polygon_2d(shape, OUTLINE_OFFSET / SPRITE_SCALE, Geometry.JOIN_ROUND)
	if grown.size() > 0:
		shape = grown[0]
		for polygon in grown:
			if polygon.size() > shape.size():
				shape = polygon

	var center_x: float = img.get_width() / 2.0
	var start: = 0
	for i in shape.size():
		var p: Vector2 = shape[i]
		var best: Vector2 = shape[start]
		if p.y < best.y - 1.0 or (abs(p.y - best.y) <= 1.0 and abs(p.x - center_x) < abs(best.x - center_x)):
			start = i

	var ordered: = PoolVector2Array()
	for i in shape.size():
		ordered.push_back(shape[(start + i) % shape.size()])
	if ordered.size() > 1 and ordered[1].x < ordered[0].x:
		var reversed_points: = PoolVector2Array([ordered[0]])
		for i in range(ordered.size() - 1, 0, - 1):
			reversed_points.push_back(ordered[i])
		ordered = reversed_points
	ordered.push_back(ordered[0])

	_outline = ordered
	_outline_lengths = [0.0]
	_outline_total = 0.0
	for i in range(1, _outline.size()):
		_outline_total += _outline[i - 1].distance_to(_outline[i])
		_outline_lengths.push_back(_outline_total)


func _get_partial_outline(ratio: float) -> PoolVector2Array:
	var points: = PoolVector2Array()
	if _outline.size() < 2 or ratio <= 0.0:
		return points
	var target: float = _outline_total * clamp(ratio, 0.0, 1.0)
	points.push_back(_outline[0])
	for i in range(1, _outline.size()):
		if _outline_lengths[i] <= target:
			points.push_back(_outline[i])
			continue
		var seg: float = _outline_lengths[i] - _outline_lengths[i - 1]
		var t: float = (target - _outline_lengths[i - 1]) / seg if seg > 0.0 else 0.0
		points.push_back(_outline[i - 1].linear_interpolate(_outline[i], t))
		break
	return points


# Progression de l'amelioration (0 -> 1 en un tiers de manche, des le depot)
func _get_upgrade_ratio() -> float:
	if upgrade_player < 0:
		return 0.0
	if upgrade_ready:
		return 1.0
	var upgrade_time: float = get_wave_duration() / 3.0
	if upgrade_time <= 0.0:
		return 1.0
	return clamp((get_elapsed_in_wave() - _upgrade_start) / upgrade_time, 0.0, 1.0)


func _draw() -> void :
	if not _active:
		if _birthing:
			_draw_birth_cross()
		return

	var is_on: bool = RunData.tinkiluz_is_machine_on()

	var phase: float = fmod(_elapsed, BOUNCE_PERIOD) / BOUNCE_PERIOD
	var squash: float = (1.0 - cos(phase * TAU)) / 2.0 * BOUNCE_SQUASH if is_on else 0.0
	var bounce_scale: = Vector2(1.0 + squash, 1.0 - squash)

	if _texture == null:
		return

	draw_set_transform(Vector2(0.0, SPRITE_FEET_OFFSET), 0.0, bounce_scale * SPRITE_SCALE)

	var size: Vector2 = _texture.get_size()
	var top_left: = Vector2( - size.x / 2.0, - size.y)

	var shadow_points: = PoolVector2Array()
	for i in 32:
		var angle: float = TAU * i / 32.0
		shadow_points.push_back(Vector2(cos(angle) * SHADOW_RADIUS.x, SHADOW_Y + sin(angle) * SHADOW_RADIUS.y))
	draw_colored_polygon(shadow_points, SHADOW_COLOR)

	if is_on and _glow_texture != null:
		var glow_d: float = size.x * GLOW_SIZE_FACTOR
		var glow_center: = Vector2(0.0, - size.y * GLOW_CENTER_Y)
		var glow_color: = GLOW_COLOR
		var base_alpha: float = GLOW_ALPHA_OPEN if is_upgrade_possible_this_wave() or upgrade_player >= 0 else GLOW_ALPHA
		glow_color.a = base_alpha + sin(_elapsed * 2.0) * GLOW_PULSE
		draw_texture_rect(_glow_texture, Rect2(glow_center - Vector2(glow_d, glow_d) / 2.0, Vector2(glow_d, glow_d)), false, glow_color)

	var tint: Color = Color.white if is_on else OFF_TINT
	if upgrade_player >= 0 and not upgrade_ready:
		var pulse: float = (sin(_elapsed * 6.0) + 1.0) / 2.0
		tint = Color.white.linear_interpolate(Color(0.6, 1.0, 1.0, 1.0), 0.2 + 0.3 * pulse)
	draw_texture_rect(_texture, Rect2(top_left, size), false, tint)

	# Bordure de progression : couleur du joueur dont l'arme est dans la machine
	if upgrade_player >= 0 and _outline.size() > 1:
		var width: float = OUTLINE_WIDTH / SPRITE_SCALE
		var color: Color = PapUtils.get_player_color(upgrade_player)
		var shifted: = PoolVector2Array()
		for p in _outline:
			shifted.push_back(p + top_left)
		draw_polyline(shifted, OUTLINE_TRACK_COLOR, width, true)

		if upgrade_ready:
			color.a = 0.55 + 0.45 * sin(_elapsed * 8.0)
			draw_polyline(shifted, color, width, true)
		else:
			var partial: PoolVector2Array = _get_partial_outline(_get_upgrade_ratio())
			if partial.size() > 1:
				var filled: = PoolVector2Array()
				for p in partial:
					filled.push_back(p + top_left)
				draw_polyline(filled, color, width, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_overlay.update()


# Dessine au-dessus des entites (calque _overlay, z_index eleve)
func draw_overlay(ci: CanvasItem) -> void :
	if not _active or _leaving:
		return
	if upgrade_ready and upgrade_weapon != null and upgrade_weapon.icon != null:
		_draw_ready_weapon(ci)
	if not _nearby.empty():
		_draw_prompt(ci)


# Icone de l'arme prete, qui flotte au-dessus de la machine
func _draw_ready_weapon(ci: CanvasItem) -> void :
	var icon: Texture = upgrade_weapon.icon
	var bob: float = sin(_elapsed * 4.0) * 4.0
	var icon_size: = Vector2(48, 48)
	var y: float = PROMPT_Y - 60.0 if not _nearby.empty() else PROMPT_Y
	ci.draw_texture_rect(icon, Rect2(Vector2( - icon_size.x / 2.0, y - icon_size.y / 2.0 + bob), icon_size), false, PapUtils.WEAPON_TINT)


# "[touche] Pack-a-Punch" au-dessus de la machine
func _draw_prompt(ci: CanvasItem) -> void :
	var player_index: int = _nearby[0]
	var text: String = tr("TINKILUZ_PAP_TAKE") if can_take_back(player_index) else tr("TINKILUZ_PAP_INTERACT")
	var icon: Texture = CoopService.get_player_key_texture("ui_accept", player_index)

	var text_size: Vector2 = FONT.get_string_size(text)
	var icon_w: float = PROMPT_ICON_SIZE if icon != null else 0.0
	var gap: float = 8.0 if icon != null else 0.0
	var total_w: float = icon_w + gap + text_size.x
	var left: float = - total_w / 2.0

	var bg_rect: = Rect2(left - 10.0, PROMPT_Y - PROMPT_ICON_SIZE / 2.0 - 6.0, total_w + 20.0, PROMPT_ICON_SIZE + 12.0)
	ci.draw_rect(bg_rect, Color(0, 0, 0, 0.55), true)
	var border: Color = PapUtils.get_player_color(player_index)
	ci.draw_rect(bg_rect, border, false, 2.0)

	if icon != null:
		ci.draw_texture_rect(icon, Rect2(Vector2(left, PROMPT_Y - PROMPT_ICON_SIZE / 2.0), Vector2(PROMPT_ICON_SIZE, PROMPT_ICON_SIZE)), false)
	var baseline: float = PROMPT_Y + FONT.get_ascent() / 2.0 - 2.0
	ci.draw_string(FONT, Vector2(left + icon_w + gap, baseline), text, Color.white)


# Calque de dessin au-dessus des entites
class Overlay extends Node2D:
	var machine = null

	func _draw() -> void :
		if machine != null:
			machine.draw_overlay(self)


func _draw_birth_cross() -> void :
	var tex_size: Vector2 = BIRTH_TEXTURE.get_size()
	var color: = BIRTH_COLOR
	color.a = _birth_alpha
	draw_set_transform(Vector2(0.0, SPRITE_FEET_OFFSET), _birth_rotation, Vector2(BIRTH_SCALE, BIRTH_SCALE))
	draw_texture(BIRTH_TEXTURE, - tex_size / 2.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
