extends "res://ui/menus/shop/coop_shop.gd"

# load() au lieu de preload() : evite le faux "cyclic reference" de l'editeur
const TINKILUZ_PAP_CONTROLLER_PATH = "res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_shop_controller.gd"

var _tinkiluz_pap_controller = null


# Godot 3 appelle automatiquement les _ready() de base_shop.gd et coop_shop.gd
# avant celui-ci : ne pas appeler ._ready().
func _ready() -> void :
	_tinkiluz_pap_controller = load(TINKILUZ_PAP_CONTROLLER_PATH).new()
	_tinkiluz_pap_controller.name = "TinkiluzPapShopController"
	add_child(_tinkiluz_pap_controller)
	_tinkiluz_pap_controller.setup(self)
