extends Reference

# Reglages du mod, tout est regroupe ici pour pouvoir les changer facilement.
#
# Deroule :
# 1. "Pack-a-Punch casse" tombe (rarement) d'une caisse. Recycle = il peut
#    retomber plus tard.
# 2. Des qu'un joueur l'a pris, la machine est sur la carte a chaque manche
#    (commune a toute l'equipe), eteinte.
# 3. On interagit avec elle : panel -> quetes pour obtenir les composants.
# 4. Tous les composants obtenus = machine allumee. Les jetons apparaissent
#    alors au magasin.
# 5. Avec un jeton, on depose une arme pendant le 1er tiers de la manche,
#    elle s'ameliore pendant le 2e tiers, il faut la recuperer pendant le 3e.
#    Pas recuperee a la fin de la manche = arme perdue.

# --- Caisses --------------------------------------------------------------------
const CRATE_CHANCE = 0.02             # chance par caisse normale
const LEGENDARY_CRATE_CHANCE = 0.08   # chance par caisse legendaire
const BROKEN_ITEM_ID = "item_tinkiluz_pap_broken"

# --- Quetes ---------------------------------------------------------------------
const QUEST_ZONE = "zone"             # id de la quete "zone"
const QUEST_LANTERNS = "lanterns"     # id de la quete "lanternes"
const QUEST_PARTS = "parts"           # id de la quete passive "pieces detachees"
const QUEST_ELITES = "elites"         # id de la quete "3 elites"
const QUEST_IDS = [QUEST_PARTS, QUEST_ZONE, QUEST_LANTERNS, QUEST_ELITES]  # une quete = un composant
# Elites de la quete "Bobine" : 1 jusqu'a la manche 14, 2 a partir de la 15
const ELITES_COUNT_MIN = 1
const ELITES_COUNT_MAX = 2
const ELITES_EXTRA_FROM_WAVE = 15     # manche ou on passe a 2 elites
const ELITES_WAVES_PER_EXTRA = 5      # +1 elite toutes les 5 manches (bloque par le max)
const PASSIVE_QUEST_IDS = [QUEST_PARTS]  # pas besoin de les lancer, ne bloquent pas les autres

# Quete passive : des que la machine est sur la carte (eteinte), les ennemis
# lachent parfois une piece detachee (pas un objet d'inventaire, juste un compteur)
const PARTS_NEEDED = 5
const PART_ID = "tinkiluz_pap_part"
const PART_CHANCE = 0.008             # chance par ennemi tue
const PART_ELITE_CHANCE = 0.5         # elites et boss
const ZONE_KILLS_PER_WAVE = 4       # kills a faire = numero de manche x 3.5
const ZONE_SPEED = 80.0               # vitesse de deplacement de la zone (px/s)
const ZONE_KILLS_MIN = 10
const ZONE_SCALE = 1.2                # taille de la zone (1 = zone du Braconnier)
const ZONE_RADIUS = 340.0             # rayon de la zone du Braconnier a l'echelle 1
const ZONE_RADIUS_FACTOR = Vector2(1.05, 0.886)  # forme de la zone du Braconnier
const ZONE_MIN_DISTANCE_FROM_EDGE = 450.0  # ~ rayon de la zone : elle reste dans l'arene
const ZONE_MIN_DISTANCE_FROM_MACHINE = 350.0

# Quete des lanternes (dans le brouillard, a allumer dans un ordre secret)
const LANTERN_COUNT_MIN = 4           # manche de 20 s
const LANTERN_COUNT_MAX = 6           # manche de 60 s et plus
const FOG_VISIBILITY = 0.5           # taille de la vision dans notre brouillard (1 = comme le jeu)
const LANTERN_RADIUS = 80.0           # distance pour allumer une lanterne
const LANTERN_LIGHT_TIME = 0.55        # secondes a rester a cote
const LANTERN_LIGHT_SCALE = 2.0       # taille de la lumiere d'une lanterne allumee
const LANTERN_MIN_DISTANCE = 500.0    # entre deux lanternes (et avec la machine)
const LANTERN_MIN_DISTANCE_FROM_EDGE = 150.0

# --- Jetons au magasin ----------------------------------------------------------
const TOKEN_ITEM_ID = "item_tinkiluz_pap_token"
const TOKEN_SHOP_CHANCE = 0.03       # chance par generation de magasin (reroll compris)
const TOKEN_VALUE = 30                # prix de base (augmente avec la manche comme les objets)

# --- Amelioration ---------------------------------------------------------------
const MIN_WAVE_DURATION = 60.0        # manche plus courte : pas d'amelioration
const MIN_WEAPON_TIER = 3             # Tier.LEGENDARY = arme tier IV
const TOKEN_COST = 1

# --- Machine en vague -----------------------------------------------------------
const SPAWN_DELAY = 1.5               # secondes apres le debut de la vague
const INTERACT_RADIUS = 110.0         # distance pour interagir (pixels)
const SPAWN_MARGIN = 250.0            # distance minimale aux bords de l'arene

# --- Visuel ---------------------------------------------------------------------
const CYAN = Color(0.0, 1.0, 1.0, 1.0)
const WEAPON_TINT = Color(0.45, 1.0, 1.0, 1.0)

# Cle de metadonnee posee sur la WeaponData amelioree
const META_KEY = "tinkiluz_pap"


static func is_pap(item) -> bool:
	return item != null and item is Object and item.has_meta(META_KEY) and item.get_meta(META_KEY) == true


static func set_pap(item, value: bool) -> void:
	if item == null:
		return
	if value:
		item.set_meta(META_KEY, true)
	elif item.has_meta(META_KEY):
		item.remove_meta(META_KEY)


# L'arme peut-elle etre amelioree (sans regarder les jetons ni le timing) ?
static func is_weapon_eligible(weapon) -> bool:
	return weapon is WeaponData and weapon.tier >= MIN_WEAPON_TIER and not is_pap(weapon)


# Kills a faire dans la zone pour la manche en cours
static func get_zone_kills_needed() -> int:
	return int(max(ZONE_KILLS_MIN, round(RunData.current_wave * ZONE_KILLS_PER_WAVE)))


# Elites a tuer pour la Bobine : manches 1-14 -> 1, 15+ -> 2
static func get_elites_count() -> int:
	var wave: int = RunData.current_wave
	if wave < ELITES_EXTRA_FROM_WAVE:
		return ELITES_COUNT_MIN
	var count: int = ELITES_COUNT_MIN + 1 + int((wave - ELITES_EXTRA_FROM_WAVE) / ELITES_WAVES_PER_EXTRA)
	return int(min(count, ELITES_COUNT_MAX))


# Nombre de lanternes selon la duree de la manche : 20 s -> 4, 40 s -> 5, 60 s -> 6
static func get_lantern_count(wave_duration: float) -> int:
	var count: int = LANTERN_COUNT_MIN + int(round((wave_duration - 20.0) / 20.0))
	return int(clamp(count, LANTERN_COUNT_MIN, LANTERN_COUNT_MAX))


# Couleur d'un joueur : cyan en solo, couleur du joueur en coop
static func get_player_color(player_index: int) -> Color:
	if not RunData.is_coop_run:
		return CYAN
	return CoopService.get_player_color(player_index)
