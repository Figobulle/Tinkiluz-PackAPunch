extends "res://singletons/run_data.gd"

# Etat Pack-a-Punch.
# - Machine trouvee : un joueur possede l'objet "Pack-a-Punch casse" (donc
#   sauvegarde automatiquement avec les objets).
# - Composants : quetes reussies, communes a toute l'equipe.
# - Jetons : un compteur par joueur.
# - Arme amelioree : metadonnee sur la WeaponData (voir pap_utils.gd).
# Tout est ajoute a l'etat de run (get_state / resume_from_state) : la
# sauvegarde du jeu recopie les cles inconnues telles quelles.

signal tinkiluz_pap_tokens_changed(new_value, player_index)
signal tinkiluz_pap_components_changed()

const TINKILUZ_STATE_KEY = "tinkiluz_pap"
const TINKILUZ_PAP_META = "tinkiluz_pap"
const TINKILUZ_TOKEN_ID = "tinkiluz_pap_token"

const TinkiluzPapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")

var tinkiluz_pap_tokens: = [0, 0, 0, 0]
var tinkiluz_quests_done: = []        # ids des quetes reussies (= composants)
var tinkiluz_parts_collected: = 0     # quete passive : pieces detachees ramassees (equipe)
var _tinkiluz_part_data = null

var _tinkiluz_token_texture: Texture = null
var _tinkiluz_token_data = null


func reset(restart: bool = false) -> void :
	.reset(restart)
	tinkiluz_pap_tokens = [0, 0, 0, 0]
	tinkiluz_quests_done = []
	tinkiluz_parts_collected = 0


# --- Quete passive : pieces detachees -----------------------------------------------

# Consommable lache par les ennemis : visuel des pieces meca, aucun effet.
# Il est attire en fin de manche comme les autres (n'importe quel joueur).
func tinkiluz_get_part_data():
	if _tinkiluz_part_data == null:
		var base = load("res://items/consumables/meca_parts/meca_parts_data.tres")
		var data = base.duplicate()
		data.my_id = TinkiluzPapUtils.PART_ID
		data.my_id_hash = Keys.generate_hash(data.my_id)
		data.name = "TINKILUZ_PAP_PART"
		var icon: Texture = ItemService.tinkiluz_load_texture("pap_part.png")
		if icon != null:
			data.icon = icon
		data.effects = []
		data.to_be_processed_at_end_of_wave = false
		_tinkiluz_part_data = data
	return _tinkiluz_part_data


func tinkiluz_is_part(consumable_data) -> bool:
	return consumable_data != null and "my_id" in consumable_data and consumable_data.my_id == TinkiluzPapUtils.PART_ID


# La quete passive est-elle en cours ? (machine trouvee, eteinte, pieces manquantes)
func tinkiluz_needs_parts() -> bool:
	return (
		tinkiluz_is_machine_found()
		and not tinkiluz_is_machine_on()
		and not tinkiluz_is_quest_done(TinkiluzPapUtils.QUEST_PARTS)
	)


func tinkiluz_add_part() -> void :
	if tinkiluz_is_quest_done(TinkiluzPapUtils.QUEST_PARTS):
		return
	tinkiluz_parts_collected += 1
	if tinkiluz_parts_collected >= TinkiluzPapUtils.PARTS_NEEDED:
		tinkiluz_complete_quest(TinkiluzPapUtils.QUEST_PARTS)


# --- Machine ----------------------------------------------------------------------

func tinkiluz_is_machine_found() -> bool:
	for player_index in players_data.size():
		if tinkiluz_has_broken_machine(player_index):
			return true
	return false


func tinkiluz_has_broken_machine(player_index: int) -> bool:
	if player_index < 0 or player_index >= players_data.size():
		return false
	for item in players_data[player_index].items:
		if item != null and item.my_id == TinkiluzPapUtils.BROKEN_ITEM_ID:
			return true
	return false


func tinkiluz_is_quest_done(quest_id: String) -> bool:
	return quest_id in tinkiluz_quests_done


func tinkiluz_complete_quest(quest_id: String) -> void :
	if tinkiluz_is_quest_done(quest_id):
		return
	tinkiluz_quests_done.push_back(quest_id)
	emit_signal("tinkiluz_pap_components_changed")


func tinkiluz_get_components_count() -> int:
	return tinkiluz_quests_done.size()


func tinkiluz_get_components_needed() -> int:
	return TinkiluzPapUtils.QUEST_IDS.size()


func tinkiluz_is_machine_on() -> bool:
	return tinkiluz_is_machine_found() and tinkiluz_get_components_count() >= tinkiluz_get_components_needed()


# --- Protection : index de joueur negatif ------------------------------------------
# Certaines sources (brulure dont la source n'a pas de joueur, index -1) font
# planter la version debug sur un assert. Le jeu publie (sans asserts) lit
# alors players_data[-1] : on fait pareil, et on note d'ou ca vient (une fois).

var _tinkiluz_negative_index_logged: = false

func get_player_effects(player_index: int) -> Dictionary:
	if player_index < 0:
		_tinkiluz_log_negative_index("effects")
		return players_data[player_index].effects
	return .get_player_effects(player_index)


func get_player_effect(key: int, player_index: int):
	if player_index < 0:
		_tinkiluz_log_negative_index(Keys.hash_to_string.get(key, str(key)))
		return players_data[player_index].effects[key]
	return .get_player_effect(key, player_index)


func _tinkiluz_log_negative_index(what: String) -> void :
	if _tinkiluz_negative_index_logged:
		return
	_tinkiluz_negative_index_logged = true
	var lines: = []
	for frame in get_stack():
		lines.push_back("%s:%s %s" % [frame.source, frame.line, frame.function])
	ModLoaderLog.warning("Index de joueur -1 (%s), corrige. Pile : %s" % [what, PoolStringArray(lines).join(" <- ")], "Tinkiluz-PackAPunch")


# --- Objets : le jeton achete au magasin n'est pas un vrai objet ------------------

func add_item(item: ItemData, player_index: int, is_selection: bool = false) -> void :
	if item != null and item.my_id == TinkiluzPapUtils.TOKEN_ITEM_ID:
		tinkiluz_add_pap_tokens(1, player_index)
		return
	.add_item(item, player_index, is_selection)


# --- Jetons -------------------------------------------------------------------------

func tinkiluz_get_pap_tokens(player_index: int) -> int:
	if player_index < 0 or player_index >= tinkiluz_pap_tokens.size():
		return 0
	return tinkiluz_pap_tokens[player_index]


func tinkiluz_add_pap_tokens(value: int, player_index: int) -> void :
	if value == 0 or player_index < 0 or player_index >= tinkiluz_pap_tokens.size():
		return
	tinkiluz_pap_tokens[player_index] = int(max(0, tinkiluz_pap_tokens[player_index] + value))
	emit_signal("tinkiluz_pap_tokens_changed", tinkiluz_pap_tokens[player_index], player_index)


func tinkiluz_remove_pap_tokens(value: int, player_index: int) -> void :
	tinkiluz_add_pap_tokens( - value, player_index)


# Retire exactement cette arme (pas une copie identique)
func tinkiluz_remove_exact_weapon(weapon: WeaponData, player_index: int) -> void :
	if player_index < 0 or player_index >= players_data.size():
		return
	var weapons: Array = players_data[player_index].weapons
	var index: int = weapons.find(weapon)
	if index < 0:
		return
	weapons.remove(index)
	after_weapon_removed(weapon, player_index)


# --- Sauvegarde ---------------------------------------------------------------

func get_state() -> Dictionary:
	var state = .get_state()

	var pap_weapons: = []
	for player_data in players_data:
		var indexes: = []
		for i in player_data.weapons.size():
			var weapon = player_data.weapons[i]
			if weapon != null and weapon.has_meta(TINKILUZ_PAP_META) and weapon.get_meta(TINKILUZ_PAP_META) == true:
				indexes.push_back(i)
		pap_weapons.push_back(indexes)

	state[TINKILUZ_STATE_KEY] = {
		"tokens": tinkiluz_pap_tokens.duplicate(),
		"quests": tinkiluz_quests_done.duplicate(),
		"parts": tinkiluz_parts_collected,
		"weapons": pap_weapons
	}
	return state


func resume_from_state(state: Dictionary) -> void :
	.resume_from_state(state)

	tinkiluz_pap_tokens = [0, 0, 0, 0]
	tinkiluz_quests_done = []
	tinkiluz_parts_collected = 0

	if not state.has(TINKILUZ_STATE_KEY) or not state[TINKILUZ_STATE_KEY] is Dictionary:
		return

	var pap_state: Dictionary = state[TINKILUZ_STATE_KEY]

	# Le JSON relit les nombres en float : on reconvertit en int
	var tokens = pap_state.get("tokens", [])
	for i in min(tokens.size(), tinkiluz_pap_tokens.size()):
		tinkiluz_pap_tokens[i] = int(tokens[i])

	tinkiluz_parts_collected = int(pap_state.get("parts", 0))

	for quest_id in pap_state.get("quests", []):
		if quest_id in TinkiluzPapUtils.QUEST_IDS and not quest_id in tinkiluz_quests_done:
			tinkiluz_quests_done.push_back(quest_id)

	var pap_weapons = pap_state.get("weapons", [])
	for player_index in min(pap_weapons.size(), players_data.size()):
		var weapons: Array = players_data[player_index].weapons
		for weapon_index in pap_weapons[player_index]:
			var idx = int(weapon_index)
			if idx >= 0 and idx < weapons.size() and weapons[idx] != null:
				weapons[idx].set_meta(TINKILUZ_PAP_META, true)


# --- Visuel du jeton ----------------------------------------------------------

const TINKILUZ_TOKEN_ICON_PATH = "res://mods-unpacked/Tinkiluz-PackAPunch/assets/pap_token.png"


# Icone du jeton : une mini machine Pack-a-Punch (64x64).
# Chargee en Image pour marcher sans import Godot.
func tinkiluz_get_token_texture() -> Texture:
	if _tinkiluz_token_texture != null:
		return _tinkiluz_token_texture

	var icon: = Image.new()
	if icon.load(TINKILUZ_TOKEN_ICON_PATH) == OK:
		var icon_tex: = ImageTexture.new()
		icon_tex.create_from_image(icon, Texture.FLAG_FILTER)
		_tinkiluz_token_texture = icon_tex
	return _tinkiluz_token_texture


# "Consommable" factice utilise uniquement pour l'affichage en haut de l'ecran
# (meme liste que les caisses / pieces meca). Il n'a aucun effet.
func tinkiluz_get_token_consumable_data():
	if _tinkiluz_token_data != null:
		return _tinkiluz_token_data

	var base = load("res://items/consumables/meca_parts/meca_parts_data.tres")
	var data = base.duplicate()
	data.my_id = TINKILUZ_TOKEN_ID
	data.my_id_hash = Keys.generate_hash(TINKILUZ_TOKEN_ID)
	data.name = "TINKILUZ_PAP_TOKEN"
	data.icon = tinkiluz_get_token_texture()
	data.effects = []
	_tinkiluz_token_data = data
	return _tinkiluz_token_data
