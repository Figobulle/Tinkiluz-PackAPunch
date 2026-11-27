extends Node2D

# Quete "Noyau du reacteur" : une zone (visuel de la zone du Braconnier,
# recoloree en cyan) apparait sur la carte. Il faut y tuer (manche x 2.5)
# ennemis avant la fin de la manche (tous les joueurs comptent).
# Reussite -> signal "completed". Fin de manche avant -> quete ratee, elle
# pourra etre relancee a une prochaine manche.

signal completed(quest_id)

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")
const ZONE_SCENE = "res://entities/gpe/poacher_zone/poacher_zone.tscn"
const MARK_SCENE = "res://entities/gpe/poacher_zone/poacher_mark.tscn"
const FONT = preload("res://resources/fonts/actual/base/font_40_outline.tres")

const ZONE_COLOR_A = Color(0.0, 0.85, 1.0, 1.0)
const ZONE_COLOR_B = Color(0.0, 0.85, 1.0, 0.45)

var quest_id: String = PapUtils.QUEST_ZONE
var main = null

var kills: = 0
var kills_needed: int = PapUtils.get_zone_kills_needed()  # fixe au lancement
var _done: = false
var _zone = null
var _mark_scene: PackedScene = null
var _label: Label = null


func _ready() -> void :
	var zone_scene: PackedScene = load(ZONE_SCENE)
	_mark_scene = load(MARK_SCENE)
	if zone_scene != null:
		_zone = zone_scene.instance()
		_zone.lifetime = - 1
		add_child(_zone)
		# Visuel seulement : on ne touche pas aux compteurs du Braconnier
		_zone.monitoring = false
		_zone.monitorable = false
		var zone_material: ShaderMaterial = _zone.sprite.material.duplicate()
		zone_material.set_shader_param("color_A", ZONE_COLOR_A)
		zone_material.set_shader_param("color_B", ZONE_COLOR_B)
		_zone.sprite.material = zone_material
		_zone.init(Vector2(PapUtils.ZONE_SCALE, PapUtils.ZONE_SCALE))

	# Compteur au centre de la zone
	_label = Label.new()
	_label.add_font_override("font", FONT)
	_label.align = Label.ALIGN_CENTER
	_label.valign = Label.VALIGN_CENTER
	_label.rect_size = Vector2(240, 60)
	_label.rect_position = - _label.rect_size / 2.0
	_label.modulate = Color(0.75, 1.0, 1.0, 0.9)
	add_child(_label)
	_refresh_label()


# La zone se deplace doucement d'un point a l'autre de l'arene
var _target: = Vector2.ZERO
var _has_target: = false

func _physics_process(delta: float) -> void :
	if _done or main == null:
		return
	if not _has_target or global_position.distance_to(_target) < 10.0:
		_target = main.tinkiluz_get_random_position(PapUtils.ZONE_MIN_DISTANCE_FROM_EDGE, [global_position], 300.0)
		_has_target = true
	global_position = global_position.move_toward(_target, PapUtils.ZONE_SPEED * delta)


func is_inside(pos: Vector2) -> bool:
	var radius: Vector2 = PapUtils.ZONE_RADIUS * PapUtils.ZONE_SCALE * PapUtils.ZONE_RADIUS_FACTOR
	var d: Vector2 = pos - global_position
	return pow(d.x / radius.x, 2) + pow(d.y / radius.y, 2) <= 1.0


func on_enemy_killed(enemy_position: Vector2) -> void :
	if _done or not is_inside(enemy_position):
		return

	kills += 1
	_refresh_label()

	if _mark_scene != null and main != null:
		var mark: Node2D = _mark_scene.instance()
		mark.global_position = enemy_position
		main._gpe_container.add_child(mark)
	if _zone != null:
		_zone._on_poacher_enemy_killed_in_zone(0, enemy_position)

	if kills >= kills_needed:
		_done = true
		emit_signal("completed", quest_id)
		remove()


func _refresh_label() -> void :
	if _label != null:
		_label.text = "%s/%s" % [kills, kills_needed]


func remove() -> void :
	_done = true
	if _label != null:
		_label.hide()
	if _zone != null and is_instance_valid(_zone):
		_zone.despawn()
	var timer: = get_tree().create_timer(0.5, false)
	timer.connect("timeout", self, "queue_free")
