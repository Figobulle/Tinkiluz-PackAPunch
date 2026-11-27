extends "res://items/global/inventory_element.gd"

# Arme Pack-a-Punch dans l'inventaire : icone teintee + bordure cyan.

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")


func set_element(item_data: Resource) -> void :
	.set_element(item_data)
	tinkiluz_refresh_pap()


func update_background_color(p_color: int = - 1) -> void :
	.update_background_color(p_color)
	tinkiluz_refresh_pap()


func tinkiluz_refresh_pap() -> void :
	if item == null or _icon == null:
		return

	var is_pap: bool = PapUtils.is_pap(item)

	# self_modulate : modulate est deja utilise par le codex (silhouette)
	_icon.self_modulate = PapUtils.WEAPON_TINT if is_pap else Color.white

	if not is_pap:
		return

	var stylebox = get_stylebox("normal")
	if stylebox is StyleBoxFlat:
		var pap_stylebox: StyleBoxFlat = stylebox.duplicate()
		pap_stylebox.border_color = PapUtils.CYAN
		pap_stylebox.border_width_left = int(max(pap_stylebox.border_width_left, 3))
		pap_stylebox.border_width_top = int(max(pap_stylebox.border_width_top, 3))
		pap_stylebox.border_width_right = int(max(pap_stylebox.border_width_right, 3))
		pap_stylebox.border_width_bottom = int(max(pap_stylebox.border_width_bottom, 3))
		add_stylebox_override("normal", pap_stylebox)
