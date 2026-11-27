extends Node2D

# Quete "Bobine" : 1 a 3 elites de la zone (selon la manche) apparaissent dans
# l'arene. Tous tues -> quete reussie. Fin de manche avant -> ratee.
# Les elites de la quete ont un double anneau cyan au sol.

signal completed(quest_id)

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")

const RING_RADIUS = 46.0
const META_KEY = "tinkiluz_pap_quest_elite"

var quest_id: String = PapUtils.QUEST_ELITES
var main = null

var _expected: = {}     # chemin de scene -> nombre d'elites encore a reconnaitre
var _elites: = []       # elites de la quete en vie
var _killed: = 0
var _count: = 1         # elites a tuer (selon la manche)
var _done: = false
var _elapsed: = 0.0


func _ready() -> void :
	var elites: Array = ZoneService.get_elites_from_zone(RunData.current_zone)
	if elites.empty():
		# Zone sans elite (ne devrait pas arriver) : quete validee d'office
		call_deferred("_complete")
		return

	_count = PapUtils.get_elites_count()   # fixe au lancement
	var hashes: = []
	for _i in _count:
		var elite = Utils.get_rand_element(elites)
		hashes.push_back(elite.my_id_hash)
		var path: String = elite.scene.resource_path
		_expected[path] = _expected.get(path, 0) + 1

	var group = main._wave_manager.init_elite_group(hashes, false)
	group.spawn_timing = main._wave_timer.wait_time - main._wave_timer.time_left
	main._wave_manager.add_groups([group])
	ModLoaderLog.info("Quete elites : %s" % str(_expected.keys()), "Tinkiluz-PackAPunch")


# Appele par main.gd pour chaque ennemi qui apparait
func on_enemy_spawned(enemy) -> void :
	if _done or not enemy is Boss:
		return
	var path: String = enemy.filename
	if _expected.get(path, 0) <= 0:
		return
	_expected[path] -= 1
	enemy.set_meta(META_KEY, true)
	_elites.push_back(enemy)


# Appele par main.gd pour chaque ennemi mort
func on_enemy_died(enemy) -> void :
	if _done or not enemy.has_meta(META_KEY):
		return
	_elites.erase(enemy)
	_killed += 1
	main.tinkiluz_show_text("%s/%s" % [_killed, _count], enemy.global_position + Vector2(0, - 80), PapUtils.CYAN)
	if _killed >= _count:
		_complete()


func _complete() -> void :
	if _done:
		return
	_done = true
	emit_signal("completed", quest_id)
	queue_free()


func remove() -> void :
	_done = true
	queue_free()


func _physics_process(delta: float) -> void :
	_elapsed += delta
	for i in range(_elites.size() - 1, - 1, - 1):
		if not is_instance_valid(_elites[i]):
			_elites.remove(i)
	update()


func _draw() -> void :
	var pulse: float = 1.0 + sin(_elapsed * 5.0) * 0.08
	for elite in _elites:
		if not is_instance_valid(elite) or elite.dead:
			continue
		var pos: Vector2 = elite.global_position - global_position
		_draw_ring(pos, RING_RADIUS * pulse, 1.0)
		_draw_ring(pos, RING_RADIUS * 1.3 * pulse, 0.5)


func _draw_ring(pos: Vector2, radius: float, alpha: float) -> void :
	var fill: = PapUtils.CYAN
	fill.a = 0.15 * alpha
	draw_circle(pos, radius, fill)
	var ring: = PapUtils.CYAN
	ring.a = alpha
	draw_arc(pos, radius, 0.0, TAU, 32, ring, 3.0, true)
