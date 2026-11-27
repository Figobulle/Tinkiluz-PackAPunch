extends "res://singletons/item_service.gd"

# Contenu du mod cote objets :
# - "Pack-a-Punch casse" : uniquement dans les caisses (jamais au magasin) ;
# - "Jeton Pack-a-Punch" : au magasin, une fois la machine allumee
#   (l'acheter ajoute un jeton, voir RunData.add_item) ;
# - les textes du mod (traductions ajoutees au TranslationServer).
#
# Les objets sont ajoutes a ItemService.items pour que la sauvegarde de run
# les retrouve par leur my_id. Ils ne sont PAS dans le pool aleatoire.

const TINKILUZ_ASSETS = "res://mods-unpacked/Tinkiluz-PackAPunch/assets/"
const TinkiluzPapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")

const TINKILUZ_TEXTS_FR = {
	"TINKILUZ_PAP_ITEM_BROKEN": "Pack-a-Punch cassé",
	"TINKILUZ_PAP_DESC_BROKEN": "Une machine apparaît sur la carte.",
	"TINKILUZ_PAP_ITEM_TOKEN": "Jeton Pack-a-Punch",
	"TINKILUZ_PAP_DESC_TOKEN": "Améliore une arme à la machine.",
	"TINKILUZ_PAP_TOKEN": "Jeton Pack-a-Punch",
	"TINKILUZ_PAP_COMPONENT": "Composant Pack-a-Punch",
	"TINKILUZ_PAP_TITLE": "Pack-a-Punch",
	"TINKILUZ_PAP_INTERACT": "Pack-a-Punch",
	"TINKILUZ_PAP_TAKE": "Récupérer l'arme",
	"TINKILUZ_PAP_UPGRADE": "Améliorer",
	"TINKILUZ_PAP_ALREADY": "Déjà améliorée.",
	"TINKILUZ_PAP_NOT_ELIGIBLE": "Seulement les armes tier IV.",
	"TINKILUZ_PAP_RESULT": "Amélioration : aura Pack-a-Punch.",
	"TINKILUZ_PAP_COMPONENTS": "Composants : {0}/{1}",
	"TINKILUZ_PAP_TOKENS": "Jetons : {0}",
	"TINKILUZ_PAP_QUEST_ZONE": "Noyau du réacteur",
	"TINKILUZ_PAP_QUEST_ZONE_DESC": "Tue {kills} ennemis dans la zone.",
	"TINKILUZ_PAP_PART": "Pièce détachée",
	"TINKILUZ_PAP_QUEST_PARTS": "Pièces détachées",
	"TINKILUZ_PAP_QUEST_PARTS_DESC": "Les ennemis lâchent des pièces. Ramassées : {n}/{max}",
	"TINKILUZ_PAP_QUEST_PASSIVE": "Quête passive : ramasse les pièces sur les ennemis.",
	"TINKILUZ_PAP_QUEST_ELITES": "Bobine",
	"TINKILUZ_PAP_QUEST_ELITES_DESC": "{n} élites apparaissent. Tue-les tous.",
	"TINKILUZ_PAP_QUEST_ELITES_DESC_ONE": "Un élite apparaît. Tue-le.",
	"TINKILUZ_PAP_LANTERNS_LIT": "Lanternes {0}/{1}",
	"TINKILUZ_PAP_QUEST_LANTERNS": "Ampoule",
	"TINKILUZ_PAP_QUEST_LANTERNS_DESC": "Le noir tombe. Allume les lanternes dans le bon ordre.",
	"TINKILUZ_PAP_QUEST_DONE": "Obtenu",
	"TINKILUZ_PAP_QUEST_RUNNING": "En cours",
	"TINKILUZ_PAP_QUEST_START": "Lancer",
	"TINKILUZ_PAP_QUEST_BUSY": "Une quête est déjà en cours.",
	"TINKILUZ_PAP_QUEST_NEXT_WAVE": "Reviens à la prochaine manche.",
	"TINKILUZ_PAP_NO_TOKEN": "Il te faut un jeton (magasin).",
	"TINKILUZ_PAP_TOO_LATE": "Trop tard pour cette manche.",
	"TINKILUZ_PAP_SHORT_WAVE": "Manche trop courte.",
	"TINKILUZ_PAP_LAST_WAVE": "Pas pendant le boss final.",
	"TINKILUZ_PAP_BUSY": "Machine occupée.",
	"TINKILUZ_PAP_NO_WEAPON": "Aucune arme tier IV à améliorer.",
	"TINKILUZ_PAP_CHOOSE": "Choisis une arme.",
	"TINKILUZ_PAP_UPGRADING": "Amélioration en cours...",
	"TINKILUZ_PAP_READY": "Arme prête !",
	"TINKILUZ_PAP_LOST": "Arme perdue !",
	"TINKILUZ_PAP_MACHINE_ON": "Pack-a-Punch allumé !",
	"TINKILUZ_PAP_ZONE_FAILED": "Quête ratée.",
}

const TINKILUZ_TEXTS_EN = {
	"TINKILUZ_PAP_ITEM_BROKEN": "Broken Pack-a-Punch",
	"TINKILUZ_PAP_DESC_BROKEN": "A machine appears on the map.",
	"TINKILUZ_PAP_ITEM_TOKEN": "Pack-a-Punch token",
	"TINKILUZ_PAP_DESC_TOKEN": "Upgrades a weapon at the machine.",
	"TINKILUZ_PAP_TOKEN": "Pack-a-Punch token",
	"TINKILUZ_PAP_COMPONENT": "Pack-a-Punch component",
	"TINKILUZ_PAP_TITLE": "Pack-a-Punch",
	"TINKILUZ_PAP_INTERACT": "Pack-a-Punch",
	"TINKILUZ_PAP_TAKE": "Take weapon",
	"TINKILUZ_PAP_UPGRADE": "Upgrade",
	"TINKILUZ_PAP_ALREADY": "Already upgraded.",
	"TINKILUZ_PAP_NOT_ELIGIBLE": "Tier IV weapons only.",
	"TINKILUZ_PAP_RESULT": "Upgrade: Pack-a-Punch aura.",
	"TINKILUZ_PAP_COMPONENTS": "Components: {0}/{1}",
	"TINKILUZ_PAP_TOKENS": "Tokens: {0}",
	"TINKILUZ_PAP_QUEST_ZONE": "Reactor core",
	"TINKILUZ_PAP_QUEST_ZONE_DESC": "Kill {kills} enemies in the zone.",
	"TINKILUZ_PAP_PART": "Spare part",
	"TINKILUZ_PAP_QUEST_PARTS": "Spare parts",
	"TINKILUZ_PAP_QUEST_PARTS_DESC": "Enemies drop spare parts. Collected: {n}/{max}",
	"TINKILUZ_PAP_QUEST_PASSIVE": "Passive quest: pick up parts dropped by enemies.",
	"TINKILUZ_PAP_QUEST_ELITES": "Coil",
	"TINKILUZ_PAP_QUEST_ELITES_DESC": "{n} elites appear. Kill them all.",
	"TINKILUZ_PAP_QUEST_ELITES_DESC_ONE": "An elite appears. Kill it.",
	"TINKILUZ_PAP_LANTERNS_LIT": "Lanterns {0}/{1}",
	"TINKILUZ_PAP_QUEST_LANTERNS": "Light bulb",
	"TINKILUZ_PAP_QUEST_LANTERNS_DESC": "Darkness falls. Light the lanterns in the right order.",
	"TINKILUZ_PAP_QUEST_DONE": "Obtained",
	"TINKILUZ_PAP_QUEST_RUNNING": "In progress",
	"TINKILUZ_PAP_QUEST_START": "Start",
	"TINKILUZ_PAP_QUEST_BUSY": "A quest is already running.",
	"TINKILUZ_PAP_QUEST_NEXT_WAVE": "Come back next wave.",
	"TINKILUZ_PAP_NO_TOKEN": "You need a token (shop).",
	"TINKILUZ_PAP_TOO_LATE": "Too late for this wave.",
	"TINKILUZ_PAP_SHORT_WAVE": "Wave too short.",
	"TINKILUZ_PAP_LAST_WAVE": "Not during the final boss.",
	"TINKILUZ_PAP_BUSY": "Machine busy.",
	"TINKILUZ_PAP_NO_WEAPON": "No tier IV weapon to upgrade.",
	"TINKILUZ_PAP_CHOOSE": "Choose a weapon.",
	"TINKILUZ_PAP_UPGRADING": "Upgrading...",
	"TINKILUZ_PAP_READY": "Weapon ready!",
	"TINKILUZ_PAP_LOST": "Weapon lost!",
	"TINKILUZ_PAP_MACHINE_ON": "Pack-a-Punch is on!",
	"TINKILUZ_PAP_ZONE_FAILED": "Quest failed.",
}

var _tinkiluz_broken_item: ItemData = null
var _tinkiluz_token_item: ItemData = null
var _tinkiluz_translations_added: = false


func _rebuild_items() -> void :
	._rebuild_items()
	_items.push_back(tinkiluz_get_broken_item())
	_items.push_back(tinkiluz_get_token_item())


func _tinkiluz_make_item(id: String, name_key: String, desc_key: String, icon_file: String, tier: int, value: int) -> ItemData:
	_tinkiluz_add_translations()

	var item = ItemData.new()
	item.my_id = id
	item.my_id_hash = Keys.generate_hash(item.my_id)
	item.name = name_key
	item.icon = tinkiluz_load_texture(icon_file)
	item.tier = tier
	item.value = value
	item.max_nb = 1
	item.unlocked_by_default = true
	item.can_be_looted = false
	item.is_lockable = true
	item.tags = []
	item.item_appearances = []
	item.tracking_text = ""

	var description = Effect.new()
	description.key = ""
	description.text_key = desc_key
	description.effect_sign = Effect.Sign.NEUTRAL
	description.custom_args = []
	item.effects = [description]
	return item


# Objet trouve dans une caisse : fait apparaitre la machine. Aucun effet.
func tinkiluz_get_broken_item() -> ItemData:
	if _tinkiluz_broken_item == null:
		_tinkiluz_broken_item = _tinkiluz_make_item(
			TinkiluzPapUtils.BROKEN_ITEM_ID, "TINKILUZ_PAP_ITEM_BROKEN", "TINKILUZ_PAP_DESC_BROKEN",
			"pap_broken.png", Tier.LEGENDARY, 0)
	return _tinkiluz_broken_item


# Quete affichee dans le panel de la machine (carte d'objet du jeu). Pas
# ajoutee a la liste des objets : elle n'est jamais possedee.
var _tinkiluz_quest_items: = {}

func tinkiluz_get_quest_item(quest_id: String) -> ItemData:
	if not _tinkiluz_quest_items.has(quest_id):
		var key: String = "TINKILUZ_PAP_QUEST_" + quest_id.to_upper()
		var item: ItemData = _tinkiluz_make_item("item_tinkiluz_pap_quest_" + quest_id, key, key + "_DESC", "pap_core.png", Tier.COMMON, 0)
		item.set_meta("tinkiluz_quest_id", quest_id)
		if quest_id == TinkiluzPapUtils.QUEST_LANTERNS:
			item.icon = load("res://dlcs/dlc_1/items/lantern/lantern_icon.png")
		elif quest_id == TinkiluzPapUtils.QUEST_PARTS:
			item.icon = tinkiluz_load_texture("pap_part.png")
		elif quest_id == TinkiluzPapUtils.QUEST_ELITES:
			item.icon = load("res://items/global/random_icon.png")
		_tinkiluz_quest_items[quest_id] = item
	# Le texte depend de la manche (nombre de kills) : remis a jour a chaque fois
	var quest_item: ItemData = _tinkiluz_quest_items[quest_id]
	# Elites : icone d'un elite de la zone en cours, si on la trouve
	if quest_id == TinkiluzPapUtils.QUEST_ELITES:
		var elites: Array = ZoneService.get_elites_from_zone(RunData.current_zone)
		if not elites.empty() and "icon" in elites[0] and elites[0].icon != null:
			quest_item.icon = elites[0].icon
	quest_item.effects[0].text_key = tinkiluz_get_quest_desc_key(quest_id)
	return quest_item


# Jeton vendu au magasin
func tinkiluz_get_token_item() -> ItemData:
	if _tinkiluz_token_item == null:
		_tinkiluz_token_item = _tinkiluz_make_item(
			TinkiluzPapUtils.TOKEN_ITEM_ID, "TINKILUZ_PAP_ITEM_TOKEN", "TINKILUZ_PAP_DESC_TOKEN",
			"pap_token.png", Tier.LEGENDARY, TinkiluzPapUtils.TOKEN_VALUE)
		_tinkiluz_token_item.max_nb = - 1
	return _tinkiluz_token_item


# Images chargees sans passer par l'import Godot (marche aussi dans un zip)
func tinkiluz_load_texture(file_name: String) -> Texture:
	var img: = Image.new()
	if img.load(TINKILUZ_ASSETS + file_name) != OK:
		return null
	var tex: = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	return tex


func _tinkiluz_add_translations() -> void :
	if _tinkiluz_translations_added:
		return
	_tinkiluz_translations_added = true

	var locales: = ["en", "fr"]
	for locale in TranslationServer.get_loaded_locales():
		if not locale in locales:
			locales.push_back(locale)

	for locale in locales:
		var texts: Dictionary = TINKILUZ_TEXTS_FR if str(locale).begins_with("fr") else TINKILUZ_TEXTS_EN
		var translation: = Translation.new()
		translation.locale = locale
		for key in texts:
			translation.add_message(key, texts[key])
		TranslationServer.add_translation(translation)
		_tinkiluz_translations.push_back([translation, texts])


# Texte avec un nombre qui change (ex : kills de la zone selon la manche) :
# on cree une cle par valeur, ajoutee aux traductions a la demande.
var _tinkiluz_translations: = []

func tinkiluz_get_formatted_key(base_key: String, args: Dictionary) -> String:
	_tinkiluz_add_translations()
	var key: String = base_key
	for arg in args:
		key += "_" + str(args[arg])
	for entry in _tinkiluz_translations:
		var translation: Translation = entry[0]
		if translation.get_message(key) == "":
			translation.add_message(key, entry[1].get(base_key, base_key).format(args))
	return key


# Description de la quete selon la manche en cours
func tinkiluz_get_quest_desc_key(quest_id: String) -> String:
	var base_key: String = "TINKILUZ_PAP_QUEST_" + quest_id.to_upper() + "_DESC"
	if quest_id == TinkiluzPapUtils.QUEST_ZONE:
		return tinkiluz_get_formatted_key(base_key, {"kills": TinkiluzPapUtils.get_zone_kills_needed()})
	if quest_id == TinkiluzPapUtils.QUEST_PARTS:
		var n: int = int(min(RunData.tinkiluz_parts_collected, TinkiluzPapUtils.PARTS_NEEDED))
		return tinkiluz_get_formatted_key(base_key, {"n": n, "max": TinkiluzPapUtils.PARTS_NEEDED})
	if quest_id == TinkiluzPapUtils.QUEST_ELITES:
		var count: int = TinkiluzPapUtils.get_elites_count()
		if count <= 1:
			return base_key + "_ONE"
		return tinkiluz_get_formatted_key(base_key, {"n": count})
	return base_key


# --- Caisses : le Pack-a-Punch casse peut sortir d'une caisse -------------------
# Tant que personne ne l'a pris. Recycle = il pourra retomber plus tard.

func process_item_box(consumable_data: ConsumableData, wave: int, player_index: int) -> ItemParentData:
	var item: ItemParentData = .process_item_box(consumable_data, wave, player_index)

	if RunData.tinkiluz_is_machine_found():
		return item

	var chance: float = TinkiluzPapUtils.CRATE_CHANCE
	if consumable_data.my_id_hash == Keys.consumable_legendary_item_box_hash:
		chance = TinkiluzPapUtils.LEGENDARY_CRATE_CHANCE

	if Utils.get_chance_success(chance):
		return tinkiluz_get_broken_item()
	return item


# --- Magasin : le jeton peut remplacer un objet du tirage -------------------------

func get_player_shop_items(wave: int, player_index: int, args: ItemServiceGetShopItemsArgs) -> Array:
	var result: Array = .get_player_shop_items(wave, player_index, args)

	if result.empty() or not RunData.tinkiluz_is_machine_on():
		return result

	var token: ItemData = tinkiluz_get_token_item()

	# Deja dans le magasin (verrouille ou dans ce tirage) : pas de doublon
	for entry in args.locked_items + result:
		if entry[0] != null and entry[0].my_id_hash == token.my_id_hash:
			return result

	if not Utils.get_chance_success(TinkiluzPapUtils.TOKEN_SHOP_CHANCE):
		return result

	# On remplace un objet (pas une arme) si possible
	var index: = result.size() - 1
	for i in range(result.size() - 1, - 1, - 1):
		if not result[i][0] is WeaponData:
			index = i
			break

	result[index] = [token, wave]
	return result
