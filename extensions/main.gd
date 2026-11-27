extends "res://main.gd"

# Pack-a-Punch en vague :
# - la machine apparait a chaque manche des qu'un joueur a le "Pack-a-Punch
#   casse" (trouve dans une caisse) ;
# - interaction -> panel (quetes si eteinte, armes si allumee) ;
# - quete "zone" : (manche x 2.5) kills dans une zone -> composant ;
# - fin de manche : arme pas recuperee = perdue, quete pas finie = ratee.

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")
const PapMachine = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_machine.gd")
const PapPanel = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_panel.gd")
const PapZoneQuest = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_zone_quest.gd")
const PapLanternQuest = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_lantern_quest.gd")
const PapEliteQuest = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_elite_quest.gd")
const PapWeaponAura = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_weapon_aura.gd")
const PAP_PICKUP_SOUND = preload("res://items/consumables/meca_parts/get_meca_part.wav")

var tinkiluz_wave_duration: = 0.0
var tinkiluz_machine = null
var _tinkiluz_quest = null          # quete en cours (noeud), une seule a la fois
var _tinkiluz_quest_started: = false  # une tentative de quete par manche
var _tinkiluz_panel = null


# Godot 3 appelle automatiquement le _ready() de main.gd avant celui-ci :
# il ne faut PAS appeler ._ready() ici, sinon tout serait initialise deux fois.
func _ready() -> void :
	tinkiluz_wave_duration = _wave_timer.wait_time
	var _e = connect("end_of_the_wave", self, "_tinkiluz_on_end_of_wave")

	if _tinkiluz_should_spawn_machine():
		_tinkiluz_spawn_machine()


# Eteinte : toujours (pour les quetes). Allumee : toujours, sauf boss final.
func _tinkiluz_should_spawn_machine() -> bool:
	if not RunData.tinkiluz_is_machine_found():
		return false
	if not RunData.tinkiluz_is_machine_on():
		return true
	# Pas de machine allumee pendant le boss final (sauf mode infini)
	return RunData.is_endless_run or RunData.current_wave < RunData.nb_of_waves


# --- Machine ---------------------------------------------------------------------

func _tinkiluz_spawn_machine() -> void :
	tinkiluz_machine = PapMachine.new()
	tinkiluz_machine.name = "TinkiluzPapMachine"
	tinkiluz_machine.main = self
	tinkiluz_machine.global_position = tinkiluz_get_random_position(PapUtils.SPAWN_MARGIN, [])
	# Meme conteneur que les consommables : dessinee sous les entites
	_consumables_container.add_child(tinkiluz_machine)


func tinkiluz_get_random_position(margin: float, avoid: Array, min_distance: float = 0.0) -> Vector2:
	var min_pos: Vector2 = ZoneService.current_zone_min_position
	var max_pos: Vector2 = ZoneService.current_zone_max_position
	var x_min = min_pos.x + margin
	var x_max = max_pos.x - margin
	var y_min = min_pos.y + margin
	var y_max = max_pos.y - margin
	if x_max <= x_min or y_max <= y_min:
		return (min_pos + max_pos) / 2.0

	var best: = Vector2(rand_range(x_min, x_max), rand_range(y_min, y_max))
	for _i in 30:
		var ok: = true
		for other in avoid:
			if best.distance_to(other) < min_distance:
				ok = false
				break
		if ok:
			break
		best = Vector2(rand_range(x_min, x_max), rand_range(y_min, y_max))
	return best


# Un joueur appuie sur la touche d'interaction a cote de la machine
func tinkiluz_on_interact(player_index: int) -> void :
	if tinkiluz_machine == null or not is_instance_valid(tinkiluz_machine):
		return
	if _tinkiluz_panel != null and is_instance_valid(_tinkiluz_panel):
		return

	var mode: = "quests"
	if tinkiluz_machine.can_take_back(player_index):
		mode = "result"
	elif RunData.tinkiluz_is_machine_on():
		mode = "weapons"

	_tinkiluz_panel = PapPanel.new()
	_tinkiluz_panel.name = "TinkiluzPapPanel"
	$UI.add_child(_tinkiluz_panel)
	_tinkiluz_panel.open(self, tinkiluz_machine, player_index, mode)


func tinkiluz_show_text(text_key: String, pos: Vector2, color: Color) -> void :
	_floating_text_manager.display(text_key, pos, color, null, 2.0, true)


# --- Quetes ------------------------------------------------------------------------

# Id de la quete en cours, "" si aucune (ou deja tentee cette manche)
func tinkiluz_get_running_quest() -> String:
	if _tinkiluz_quest != null and is_instance_valid(_tinkiluz_quest):
		return _tinkiluz_quest.quest_id
	if _tinkiluz_quest_started:
		return "-"
	return ""


func tinkiluz_start_quest(quest_id: String) -> void :
	if tinkiluz_get_running_quest() != "" or RunData.tinkiluz_is_quest_done(quest_id):
		return

	var avoid: = []
	if tinkiluz_machine != null and is_instance_valid(tinkiluz_machine):
		avoid.push_back(tinkiluz_machine.global_position)

	match quest_id:
		PapUtils.QUEST_ZONE:
			_tinkiluz_quest = PapZoneQuest.new()
			_tinkiluz_quest.global_position = tinkiluz_get_random_position(PapUtils.ZONE_MIN_DISTANCE_FROM_EDGE, avoid, PapUtils.ZONE_MIN_DISTANCE_FROM_MACHINE)
		PapUtils.QUEST_LANTERNS:
			_tinkiluz_quest = PapLanternQuest.new()
		PapUtils.QUEST_ELITES:
			_tinkiluz_quest = PapEliteQuest.new()
		_:
			return

	_tinkiluz_quest.name = "TinkiluzPapQuest"
	_tinkiluz_quest.main = self
	_gpe_container.add_child(_tinkiluz_quest)
	var _e = _tinkiluz_quest.connect("completed", self, "_tinkiluz_on_quest_completed")
	_tinkiluz_quest_started = true
	ModLoaderLog.info("Quete Pack-a-Punch lancee : %s" % quest_id, "Tinkiluz-PackAPunch")


func _tinkiluz_on_quest_completed(quest_id: String) -> void :
	# (la quete passive se termine sans toucher a la quete en cours)
	if _tinkiluz_quest != null and is_instance_valid(_tinkiluz_quest) and _tinkiluz_quest.quest_id == quest_id:
		_tinkiluz_quest = null
	RunData.tinkiluz_complete_quest(quest_id)
	SoundManager.play(PAP_PICKUP_SOUND, 0, 0.1, true)

	var pos: Vector2 = tinkiluz_machine.global_position if tinkiluz_machine != null and is_instance_valid(tinkiluz_machine) else _players[0].global_position
	if RunData.tinkiluz_is_machine_on():
		tinkiluz_show_text("TINKILUZ_PAP_MACHINE_ON", pos + Vector2(0, - 150), PapUtils.CYAN)
	else:
		tinkiluz_show_text("TINKILUZ_PAP_COMPONENT", pos + Vector2(0, - 150), PapUtils.CYAN)
	ModLoaderLog.info("Quete Pack-a-Punch reussie : %s" % quest_id, "Tinkiluz-PackAPunch")


func _on_EntitySpawner_enemy_spawned(enemy: Enemy) -> void :
	._on_EntitySpawner_enemy_spawned(enemy)
	if _tinkiluz_quest != null and is_instance_valid(_tinkiluz_quest) and _tinkiluz_quest.has_method("on_enemy_spawned"):
		_tinkiluz_quest.on_enemy_spawned(enemy)


func _on_enemy_died(enemy: Enemy, args: Entity.DieArgs) -> void :
	._on_enemy_died(enemy, args)

	# Elites de la quete : toute mort compte (meme hors kill direct)
	if not _cleaning_up and _tinkiluz_quest != null and is_instance_valid(_tinkiluz_quest) and _tinkiluz_quest.has_method("on_enemy_died"):
		_tinkiluz_quest.on_enemy_died(enemy)

	if _cleaning_up or not args.enemy_killed_by_player:
		return
	_tinkiluz_try_drop_part(enemy)
	if _tinkiluz_quest != null and is_instance_valid(_tinkiluz_quest) and _tinkiluz_quest.has_method("on_enemy_killed"):
		_tinkiluz_quest.on_enemy_killed(enemy.global_position)


# --- Quete passive : pieces detachees ------------------------------------------------

func _tinkiluz_try_drop_part(enemy: Enemy) -> void :
	if not RunData.tinkiluz_needs_parts():
		return
	# Pas plus de pieces au sol que celles qui manquent
	if RunData.tinkiluz_parts_collected + _tinkiluz_count_parts_on_ground() >= PapUtils.PARTS_NEEDED:
		return
	var chance: float = PapUtils.PART_ELITE_CHANCE if enemy is Boss else PapUtils.PART_CHANCE
	if not Utils.get_chance_success(chance):
		return
	var pos: Vector2 = enemy.global_position
	spawn_consumable(RunData.tinkiluz_get_part_data(), pos, pos)


func _tinkiluz_count_parts_on_ground() -> int:
	var count: = 0
	for consumable in _consumables:
		if is_instance_valid(consumable) and not consumable.already_picked_up and RunData.tinkiluz_is_part(consumable.consumable_data):
			count += 1
	return count


func on_consumable_picked_up(consumable: Node, player_index: int) -> void :
	var data = consumable.consumable_data
	var already: bool = consumable.already_picked_up
	.on_consumable_picked_up(consumable, player_index)

	if already or not RunData.tinkiluz_is_part(data):
		return

	RunData.tinkiluz_add_part()
	var pos: Vector2 = consumable.global_position + Vector2(0, - 40)
	var text: String = "%s/%s" % [min(RunData.tinkiluz_parts_collected, PapUtils.PARTS_NEEDED), PapUtils.PARTS_NEEDED]
	_floating_text_manager.display(text, pos, PapUtils.CYAN, data.icon, 1.5, true, Vector2.UP, false)
	if RunData.tinkiluz_is_quest_done(PapUtils.QUEST_PARTS) and RunData.tinkiluz_parts_collected == PapUtils.PARTS_NEEDED:
		_tinkiluz_on_quest_completed(PapUtils.QUEST_PARTS)


# --- Fin de manche -------------------------------------------------------------------

func _tinkiluz_on_end_of_wave() -> void :
	if _tinkiluz_panel != null and is_instance_valid(_tinkiluz_panel):
		_tinkiluz_panel.close()

	if _tinkiluz_quest != null and is_instance_valid(_tinkiluz_quest):
		var text_pos: Vector2 = _tinkiluz_quest.global_position
		if _tinkiluz_quest.quest_id != PapUtils.QUEST_ZONE and is_instance_valid(_players[0]):
			text_pos = _players[0].global_position + Vector2(0, - 100)
		tinkiluz_show_text("TINKILUZ_PAP_ZONE_FAILED", text_pos, Color(ProgressData.settings.color_negative))
		_tinkiluz_quest.remove()
		_tinkiluz_quest = null

	if tinkiluz_machine != null and is_instance_valid(tinkiluz_machine):
		tinkiluz_machine.on_wave_ended()
		tinkiluz_machine = null


# --- Armes en jeu ------------------------------------------------------------------

func _tinkiluz_get_weapon_nodes(player_index: int, weapon_data) -> Array:
	var result: = []
	if player_index < 0 or player_index >= _players.size():
		return result
	var player = _players[player_index]
	if player == null or not is_instance_valid(player):
		return result
	var index: int = RunData.get_player_weapons_ref(player_index).find(weapon_data)
	if index < 0:
		return result
	for weapon in player.current_weapons:
		if is_instance_valid(weapon) and weapon.weapon_pos == index:
			result.push_back(weapon)
	return result


# Arme deposee dans la machine : cachee et inactive (elle ne tire plus)
func tinkiluz_set_weapon_enabled(player_index: int, weapon_data, enabled: bool) -> void :
	for weapon in _tinkiluz_get_weapon_nodes(player_index, weapon_data):
		weapon.visible = enabled
		weapon.set_process(enabled)
		weapon.set_physics_process(enabled)
		if not enabled:
			weapon.disable_hitbox()
			weapon._current_target = []


func _on_EntitySpawner_players_spawned(players: Array) -> void :
	._on_EntitySpawner_players_spawned(players)
	tinkiluz_tint_pap_weapons()


func tinkiluz_tint_pap_weapons() -> void :
	for player in _players:
		if player == null or not is_instance_valid(player):
			continue

		var weapons_data: Array = RunData.get_player_weapons_ref(player.player_index)

		for weapon in player.current_weapons:
			if not is_instance_valid(weapon):
				continue
			if weapon.weapon_pos < 0 or weapon.weapon_pos >= weapons_data.size():
				continue
			if not PapUtils.is_pap(weapons_data[weapon.weapon_pos]):
				continue

			weapon.sprite.self_modulate = PapUtils.WEAPON_TINT
			PapWeaponAura.add_to(weapon)
			if "outline_sprite" in weapon and is_instance_valid(weapon.outline_sprite):
				weapon.outline_sprite.visible = true
				weapon.outline_sprite.modulate = PapUtils.CYAN
