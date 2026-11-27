extends Node

const MOD_ID = "Tinkiluz-PackAPunch"


func _init():
	var dir = ModLoaderMod.get_unpacked_dir().plus_file(MOD_ID).plus_file("extensions")

	# Etat du mod (machine trouvee, composants, jetons, armes ameliorees) + sauvegarde
	ModLoaderMod.install_script_extension(dir.plus_file("singletons/run_data.gd"))
	# Pack-a-Punch casse dans les caisses + jeton au magasin + textes
	ModLoaderMod.install_script_extension(dir.plus_file("singletons/item_service.gd"))
	# Machine en vague, panel, quete, amelioration, teinte des armes en jeu
	ModLoaderMod.install_script_extension(dir.plus_file("main.gd"))
	# Magasin solo et coop : compteur de jetons
	ModLoaderMod.install_script_extension(dir.plus_file("ui/menus/shop/shop.gd"))
	ModLoaderMod.install_script_extension(dir.plus_file("ui/menus/shop/coop_shop.gd"))
	# Icone d'arme teintee en cyan dans l'inventaire
	ModLoaderMod.install_script_extension(dir.plus_file("items/global/inventory_element.gd"))

	ModLoaderLog.info("PackAPunch 0.3.0 charge", MOD_ID)
