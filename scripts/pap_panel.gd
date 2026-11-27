extends Control

# Panel du Pack-a-Punch, en bas au milieu de l'ecran, fait avec les elements
# du jeu : carte d'objet (ItemPanelUI), cases d'inventaire (InventoryElement)
# et boutons de menu (MyMenuButton, theme panel_button_theme).
#
# Un seul panel, controle uniquement par le joueur qui l'a ouvert, jeu en
# pause tant qu'il esst ouvert. Modes :
# - "quests"  : machine eteinte, liste des quetes (une quete = un composant)
# - "weapons" : machine allumee, armes du joueur a deposer dans la machine
# - "result"  : arme prete, on voit ce qui a ete ameliore et on la recupere
#
# Navigation : le focus Godot est deplace par nous (fleches / stick / croix
# du joueur proprietaire), valider = appuyer sur l'element en focus,
# annuler / pause = fermer. La souris marche normalement.

const PapUtils = preload("res://mods-unpacked/Tinkiluz-PackAPunch/scripts/pap_utils.gd")

const BASE_THEME = preload("res://resources/themes/base_theme.tres")
const BUTTON_THEME = preload("res://resources/themes/panel_button_theme.tres")
const BUTTON_SCRIPT = preload("res://ui/menus/global/my_menu_button.gd")
# 3 niveaux de texte seulement : titre, sous-titre, texte
const FONT_TITLE = preload("res://resources/fonts/actual/base/font_35_outline.tres")
const FONT_SUBTITLE = preload("res://resources/fonts/actual/base/font_32_outline.tres")
const FONT_TEXT = preload("res://resources/fonts/actual/base/font_26.tres")
const TEXT_COLOR = Color(0.88, 0.88, 0.88, 1.0)       # comme les boutons du jeu
const MUTED_COLOR = Color(0.6, 0.6, 0.6, 1.0)
const FOCUS_TEXT_COLOR = Color(0, 0, 0, 1.0)          # texte sur bouton en focus
const BUTTON_DISABLED_COLOR = Color(0.9, 0.9, 0.9, 0.2)  # valeur du theme du jeu
const DONE_BUTTON_COLOR = Color(0.25, 0.65, 0.3, 1.0)    # fond du bouton "Obtenu"
const FONT_BUTTON = preload("res://resources/fonts/actual/base/font_menus.tres")
const ITEM_PANEL_SCENE = preload("res://ui/menus/ingame/item_panel_ui.tscn")
const ELEMENT_SCENE = preload("res://items/global/inventory_element.tscn")

const BOTTOM_MARGIN = 30.0
const ELEMENT_SIZE = Vector2(96, 96)
const DISABLED_MODULATE = Color(0.45, 0.45, 0.45, 1.0)
const DONE_MODULATE = Color(0.85, 0.85, 0.85, 1.0)
const CHECKMARK = preload("res://ui/menus/global/big_checkmark.png")

var main = null
var machine = null
var player_index: = 0
var mode: = ""

var _closing: = false
var _accept_armed: = false   # on attend que la touche d'ouverture soit relachee
var _action_enabled: = false
var _elements: = []          # InventoryElement
var _spacers: = []           # espace entre quetes a lancer et quetes passives
const PASSIVE_GAP = 40.0
var _element_data: = []      # {data, enabled, reason}
var _selected: = - 1         # element choisi (celui decrit)

const ROW_SIZE = Vector2(390, 58)
const RIGHT_WIDTH = 480.0
const ROW_ICON_SIZE = Vector2(42, 42)
const LIST_GAP = 18.0
const DETAIL_NAME_COLOR = Color(1.0, 0.85, 0.45, 1.0)
const DONE_COLOR = Color(0.45, 1.0, 0.5, 1.0)

var _replaced: = false
var _row_labels: = []        # textes de chaque ligne de quete (couleur selon le focus)
var _panel: PanelContainer = null
var _list_box: VBoxContainer = null
var _detail_name: Label = null
var _status: Label = null
var _item_panel = null
var _title: Label = null
var _info: Label = null
var _elements_box: HBoxContainer = null
var _message: Label = null
var _action_button: Button = null
var _close_button: Button = null


func _ready() -> void :
	pause_mode = Node.PAUSE_MODE_PROCESS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = BASE_THEME
	_build()


func open(p_main, p_machine, p_player_index: int, p_mode: String) -> void :
	main = p_main
	machine = p_machine
	player_index = p_player_index
	mode = p_mode
	_closing = false
	_accept_armed = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Utils.set_default_cursor()
	_refresh()
	show()


func close() -> void :
	if _closing:
		return
	_closing = true
	hide()
	if main != null and is_instance_valid(main):
		# Echap sert aussi a la pause : on evite qu'elle s'ouvre juste apres
		main._skip_pause_check = true
	get_tree().paused = false
	queue_free()


func _process(_delta: float) -> void :
	# Quelqu'un d'autre a enleve la pause (perte de focus...) : on ferme
	if not _closing and not get_tree().paused:
		close()


# --- Construction ------------------------------------------------------------------

func _build() -> void :
	_panel = PanelContainer.new()
	add_child(_panel)

	var margin: = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var root: = VBoxContainer.new()
	root.add_constant_override("separation", 22)
	margin.add_child(root)

	# En-tete sur toute la largeur : titre a gauche, avancement a droite
	var header: = HBoxContainer.new()
	root.add_child(header)

	_title = Label.new()
	_title.add_font_override("font", FONT_TITLE)
	_title.text = tr("TINKILUZ_PAP_TITLE")
	header.add_child(_title)

	_info = Label.new()
	_info.add_font_override("font", FONT_TEXT)
	_info.add_color_override("font_color", MUTED_COLOR)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.align = Label.ALIGN_RIGHT
	_info.valign = Label.VALIGN_CENTER
	_info.size_flags_vertical = Control.SIZE_FILL
	header.add_child(_info)

	var hbox: = HBoxContainer.new()
	hbox.add_constant_override("separation", 24)
	root.add_child(hbox)

	# Quetes : liste verticale a gauche (une ligne par quete)
	_list_box = VBoxContainer.new()
	_list_box.add_constant_override("separation", 6)
	_list_box.rect_min_size = Vector2(ROW_SIZE.x, 0)
	_list_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_list_box)

	_item_panel = ITEM_PANEL_SCENE.instance()
	_item_panel.rect_min_size = Vector2(340, 0)
	_item_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_item_panel)

	var right: = VBoxContainer.new()
	right.add_constant_override("separation", 18)
	right.rect_min_size = Vector2(RIGHT_WIDTH, 0)
	hbox.add_child(right)

	_elements_box = HBoxContainer.new()
	_elements_box.add_constant_override("separation", 8)
	right.add_child(_elements_box)

	# Quetes : nom de la quete choisie (sous-titre)
	_detail_name = Label.new()
	_detail_name.add_font_override("font", FONT_SUBTITLE)
	right.add_child(_detail_name)

	_message = Label.new()
	_message.add_font_override("font", FONT_TEXT)
	_message.autowrap = true
	_message.rect_min_size.x = RIGHT_WIDTH   # sinon hauteur fausse au retour a la ligne
	right.add_child(_message)

	# Quetes : etat (obtenu, deja une quete en cours...)
	_status = Label.new()
	_status.add_font_override("font", FONT_TEXT)
	_status.autowrap = true
	_status.rect_min_size.x = RIGHT_WIDTH
	right.add_child(_status)

	# Boutons en bas de la colonne
	var push: = Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(push)

	var buttons: = HBoxContainer.new()
	buttons.add_constant_override("separation", 12)
	right.add_child(buttons)

	_action_button = _make_button()
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_action_button)
	var _e = _action_button.connect("pressed", self, "_on_action_pressed")

	# Fermer : bouton carre avec la croix du jeu
	_close_button = _make_button()
	_close_button.text = ""
	_close_button.icon = load("res://ui/menus/global/cross_icon..png")
	_close_button.icon_align = Button.ALIGN_CENTER
	_close_button.rect_min_size = Vector2(64, 0)
	buttons.add_child(_close_button)
	_e = _close_button.connect("pressed", self, "close")


func _make_button() -> Button:
	var button: = Button.new()
	button.set_script(BUTTON_SCRIPT)
	button.theme = BUTTON_THEME
	button.add_font_override("font", FONT_BUTTON)
	button.focus_mode = Control.FOCUS_ALL
	button.rect_min_size = Vector2(160, 0)
	return button


func _place_panel() -> void :
	if _closing:
		return
	_panel.rect_size = Vector2.ZERO
	var size: Vector2 = _panel.get_combined_minimum_size()
	var view: Vector2 = get_viewport_rect().size
	_panel.rect_size = size
	_panel.rect_position = Vector2((view.x - size.x) / 2.0, view.y - size.y - BOTTOM_MARGIN)
	# Les textes a la ligne ne connaissent leur hauteur qu'apres un affichage :
	# on replace une 2e fois a la frame suivante
	if not _replaced:
		_replaced = true
		yield(get_tree(), "idle_frame")
		_place_panel()
		_replaced = false


# --- Contenu -----------------------------------------------------------------------

func _refresh() -> void :
	for element in _elements + _spacers:
		element.queue_free()
	_elements.clear()
	_spacers.clear()
	_row_labels.clear()
	_element_data.clear()
	_selected = - 1

	var quests: bool = mode == "quests"
	_list_box.visible = quests
	_item_panel.visible = not quests
	_detail_name.visible = quests
	_status.text = ""

	match mode:
		"quests":
			_fill_quests()
		"weapons":
			_fill_weapons()
		"result":
			_fill_result()

	_elements_box.visible = not quests and not _elements.empty()
	_status.visible = _status.text != ""

	# Premier element disponible, sinon le premier
	var first: = - 1
	for i in _element_data.size():
		if _element_data[i].enabled:
			first = i
			break
	if first < 0 and not _element_data.empty():
		first = 0
	if first >= 0:
		_select(first)
		_elements[first].grab_focus()
	else:
		_update_action_button()
		var focus: Button = _action_button if _action_enabled else _close_button
		focus.grab_focus()

	call_deferred("_place_panel")


func _add_element(data, enabled: bool, reason: String) -> void :
	var element = ELEMENT_SCENE.instance()
	_elements_box.add_child(element)
	element.set_element(data)
	element.set_element_size(ELEMENT_SIZE)
	if reason == "TINKILUZ_PAP_QUEST_DONE":
		# Quete faite : coche verte du jeu dans le coin
		var check: = TextureRect.new()
		check.texture = CHECKMARK
		check.expand = true
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.rect_size = Vector2(52, 52)
		check.rect_position = ELEMENT_SIZE - Vector2(46, 46)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		element.add_child(check)
		element.modulate = DONE_MODULATE
	elif not enabled:
		element.modulate = DISABLED_MODULATE
	var index: int = _elements.size()
	var _e = element.connect("element_focused", self, "_on_element_focused", [index])
	_e = element.connect("element_hovered", self, "_on_element_focused", [index])
	_e = element.connect("element_pressed", self, "_on_element_pressed", [index])
	_elements.push_back(element)
	_element_data.push_back({"data": data, "enabled": enabled, "reason": reason})


func _fill_quests() -> void :
	_info.text = tr("TINKILUZ_PAP_COMPONENTS").format([RunData.tinkiluz_get_components_count(), RunData.tinkiluz_get_components_needed()])
	_action_button.text = tr("TINKILUZ_PAP_QUEST_START")

	var running: String = main.tinkiluz_get_running_quest()

	# Quetes a lancer d'abord, puis les quetes passives a droite, apres un espace
	var ordered: = []
	for quest_id in PapUtils.QUEST_IDS:
		if not quest_id in PapUtils.PASSIVE_QUEST_IDS:
			ordered.push_back(quest_id)
	var first_passive: int = ordered.size()
	for quest_id in PapUtils.PASSIVE_QUEST_IDS:
		ordered.push_back(quest_id)

	for quest_id in ordered:
		if _elements.size() == first_passive and first_passive > 0:
			var spacer: = Control.new()
			spacer.rect_min_size = Vector2(0, LIST_GAP)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list_box.add_child(spacer)
			_spacers.push_back(spacer)
		var reason: = ""
		if RunData.tinkiluz_is_quest_done(quest_id):
			reason = "TINKILUZ_PAP_QUEST_DONE"
		elif quest_id in PapUtils.PASSIVE_QUEST_IDS:
			reason = "TINKILUZ_PAP_QUEST_PASSIVE"
		elif running == "-":
			reason = "TINKILUZ_PAP_QUEST_NEXT_WAVE"
		elif running != "":
			reason = "TINKILUZ_PAP_QUEST_BUSY"
		_add_quest_row(quest_id, reason)


# Une ligne de la liste des quetes : bouton du jeu avec icone, nom, et a droite
# la coche (obtenu) ou le compteur (quete passive)
func _add_quest_row(quest_id: String, reason: String) -> void :
	var data = ItemService.tinkiluz_get_quest_item(quest_id)
	var enabled: bool = reason == "" or reason == "TINKILUZ_PAP_QUEST_PASSIVE"
	var launchable: bool = reason == ""

	var row: Button = _make_button()
	row.text = ""
	row.rect_min_size = ROW_SIZE
	_list_box.add_child(row)

	var content: = HBoxContainer.new()
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.margin_left = 12
	content.margin_right = - 12
	content.add_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)

	var icon: = TextureRect.new()
	icon.texture = data.icon
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.rect_min_size = ROW_ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var title: = Label.new()
	title.add_font_override("font", FONT_TEXT)
	title.text = tr(data.name)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	content.add_child(title)
	var labels: = [title]

	if reason == "TINKILUZ_PAP_QUEST_DONE":
		var check: = TextureRect.new()
		check.texture = CHECKMARK
		check.expand = true
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.rect_min_size = Vector2(36, 36)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(check)
	elif quest_id == PapUtils.QUEST_PARTS:
		var count: = Label.new()
		count.add_font_override("font", FONT_TEXT)
		count.text = "%d/%d" % [int(min(RunData.tinkiluz_parts_collected, PapUtils.PARTS_NEEDED)), PapUtils.PARTS_NEEDED]
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(count)
		labels.push_back(count)
	_row_labels.push_back(labels)
	_color_row(row, labels)
	var _f = row.connect("focus_exited", self, "_color_row", [row, labels])

	# Pas lancable (quete en cours, prochaine manche) : grisee mais on peut
	# quand meme la selectionner pour lire pourquoi
	if not enabled:
		row.modulate = DISABLED_MODULATE

	var index: int = _elements.size()
	var _e = row.connect("focus_entered", self, "_on_row_focused", [index])
	_e = row.connect("mouse_entered", self, "_on_row_hovered", [index])
	_e = row.connect("pressed", self, "_on_row_pressed", [index])
	_elements.push_back(row)
	_element_data.push_back({"data": data, "enabled": launchable, "reason": reason})


func _fill_weapons() -> void :
	_info.text = tr("TINKILUZ_PAP_TOKENS").format([RunData.tinkiluz_get_pap_tokens(player_index)])
	_action_button.text = tr("TINKILUZ_PAP_UPGRADE")

	var wave_reason: String = machine.get_upgrade_wave_block_reason()
	if wave_reason == "TINKILUZ_PAP_BUSY" and machine.upgrade_player == player_index:
		wave_reason = "TINKILUZ_PAP_UPGRADING"
	if wave_reason == "" and RunData.tinkiluz_get_pap_tokens(player_index) < PapUtils.TOKEN_COST:
		wave_reason = "TINKILUZ_PAP_NO_TOKEN"

	for weapon in RunData.get_player_weapons_ref(player_index):
		var reason: String = wave_reason
		if reason == "":
			if PapUtils.is_pap(weapon):
				reason = "TINKILUZ_PAP_ALREADY"
			elif not PapUtils.is_weapon_eligible(weapon):
				reason = "TINKILUZ_PAP_NOT_ELIGIBLE"
		_add_element(weapon, reason == "", reason)

	if _elements.empty():
		_set_message(tr("TINKILUZ_PAP_NO_WEAPON"), true)


func _fill_result() -> void :
	_info.text = ""
	_action_button.text = tr("TINKILUZ_PAP_TAKE")
	var weapon: WeaponData = machine.upgrade_weapon
	if weapon != null:
		_show_in_card(weapon, true)
	_set_message(tr("TINKILUZ_PAP_RESULT"), false)
	_update_action_button()


func _select(index: int) -> void :
	if index < 0 or index >= _element_data.size():
		return
	_selected = index
	var entry: Dictionary = _element_data[index]

	if mode == "quests":
		# Detail a droite : nom, description, etat
		_detail_name.text = tr(entry.data.name)
		_set_message(tr(ItemService.tinkiluz_get_quest_desc_key(entry.data.get_meta("tinkiluz_quest_id"))), false)
		var reason: String = entry.reason
		# "Obtenu" s'affiche dans le bouton, les autres blocages en dessous du texte
		var done: bool = reason == "TINKILUZ_PAP_QUEST_DONE"
		_action_button.text = tr(reason) if done else tr("TINKILUZ_PAP_QUEST_START")
		_action_button.add_color_override("font_color_disabled", Color.white if done else BUTTON_DISABLED_COLOR)
		_action_button.add_stylebox_override("disabled", _get_done_style() if done else null)
		_status.text = "" if reason in ["", "TINKILUZ_PAP_QUEST_PASSIVE", "TINKILUZ_PAP_QUEST_DONE"] else tr(reason)
		_status.add_color_override("font_color", DONE_COLOR if reason == "TINKILUZ_PAP_QUEST_DONE" else Color(ProgressData.settings.color_negative))
		_status.visible = _status.text != ""
		_update_action_button()
		call_deferred("_place_panel")
		return

	_show_in_card(entry.data, PapUtils.is_pap(entry.data))
	# Grande coche du jeu sur la carte si la quete est faite
	_item_panel.selected = entry.reason == "TINKILUZ_PAP_QUEST_DONE"
	if entry.enabled:
		var text: String = tr("TINKILUZ_PAP_CHOOSE") if mode == "weapons" else tr(ItemService.tinkiluz_get_quest_desc_key(entry.data.get_meta("tinkiluz_quest_id")))
		_set_message(text, false)
	else:
		_set_message(tr(entry.reason), not entry.reason in ["TINKILUZ_PAP_QUEST_PASSIVE", "TINKILUZ_PAP_QUEST_DONE"])
	_update_action_button()


# Carte d'objet du jeu, sans la hauteur minimale de la zone de defilement
# (sinon grand vide en bas), icone teintee si l'arme est Pack-a-Punchee
func _show_in_card(data, tinted: bool) -> void :
	_item_panel.set_data(data, player_index)
	var description = _item_panel._item_description
	if description._icon != null:
		description._icon.self_modulate = PapUtils.WEAPON_TINT if tinted else Color.white
	call_deferred("_fit_card")


func _fit_card() -> void :
	if _closing:
		return
	var description = _item_panel._item_description
	var scroll = description.get_scroll_container()
	if scroll != null and scroll.get_child_count() > 0:
		var content_h: float = scroll.get_child(0).get_combined_minimum_size().y
		scroll.rect_min_size.y = min(content_h, description._default_scroll_min_height)
	description.rect_size.y = 0
	_item_panel.rect_size = Vector2.ZERO
	_place_panel()


func _update_action_button() -> void :
	var enabled: bool
	if mode == "result":
		enabled = machine != null and is_instance_valid(machine) and machine.can_take_back(player_index)
	else:
		enabled = _selected >= 0 and _element_data[_selected].enabled
	_action_enabled = enabled
	_action_button.disabled = not enabled
	_action_button.cancel_press_delay()


func _set_message(text: String, negative: bool) -> void :
	_message.text = text
	_message.add_color_override("font_color", Color(ProgressData.settings.color_negative) if negative else TEXT_COLOR)


# --- Actions -----------------------------------------------------------------------

func _on_element_focused(_element, index: int) -> void :
	_select(index)


func _on_row_focused(index: int) -> void :
	_color_row(_elements[index], _row_labels[index])
	_select(index)


# Fond vert du bouton "Obtenu" : meme forme que les boutons du jeu
var _done_style: StyleBox = null

func _get_done_style() -> StyleBox:
	if _done_style == null:
		_done_style = BUTTON_THEME.get_stylebox("normal", "Button").duplicate()
		if _done_style is StyleBoxFlat:
			_done_style.bg_color = DONE_BUTTON_COLOR
	return _done_style


# Texte noir sur la ligne en focus (fond clair), gris clair sinon : comme les boutons du jeu
func _color_row(row: Control, labels: Array) -> void :
	var color: Color = FOCUS_TEXT_COLOR if row.has_focus() else TEXT_COLOR
	for label in labels:
		label.add_color_override("font_color", color)


func _on_row_hovered(index: int) -> void :
	if not _closing:
		_elements[index].grab_focus()


func _on_row_pressed(index: int) -> void :
	_on_element_pressed(null, index)


func _on_element_pressed(_element, index: int) -> void :
	_select(index)
	if _action_enabled:
		_action_button.grab_focus()


func _on_action_pressed() -> void :
	# (MyMenuButton se desactive lui-meme une fraction de seconde au clic)
	if _closing or not _action_enabled:
		return

	match mode:
		"quests":
			if _selected >= 0:
				main.tinkiluz_start_quest(_element_data[_selected].data.get_meta("tinkiluz_quest_id"))
			close()
		"weapons":
			if _selected >= 0 and machine.start_upgrade(player_index, _element_data[_selected].data):
				close()
			else:
				_refresh()
		"result":
			machine.take_back(player_index)
			close()


# --- Entrees -----------------------------------------------------------------------
# Tout ce qui n'est pas souris passe par ici : on ne garde que les entrees du
# joueur proprietaire, et on deplace nous-memes le focus.

func _input(event: InputEvent) -> void :
	if _closing or not visible:
		return
	if event is InputEventMouse:
		return

	get_tree().set_input_as_handled()

	if Utils.is_player_action_released(event, player_index, "ui_accept"):
		_accept_armed = true
		return

	if Utils.is_player_action_released(event, player_index, "ui_cancel") or Utils.is_player_action_released(event, player_index, "ui_pause"):
		close()
		return

	if Utils.is_player_action_pressed(event, player_index, "ui_accept"):
		if _accept_armed and not event.is_echo():
			_press_focused()
	elif Utils.is_player_action_pressed(event, player_index, "ui_left"):
		_move_focus(Vector2.LEFT)
	elif Utils.is_player_action_pressed(event, player_index, "ui_right"):
		_move_focus(Vector2.RIGHT)
	elif Utils.is_player_action_pressed(event, player_index, "ui_up"):
		_move_focus(Vector2.UP)
	elif Utils.is_player_action_pressed(event, player_index, "ui_down"):
		_move_focus(Vector2.DOWN)


func _get_buttons() -> Array:
	var result: = []
	if _action_enabled:
		result.push_back(_action_button)
	result.push_back(_close_button)
	return result


func _move_focus(direction: Vector2) -> void :
	var focused: Control = get_focus_owner()
	var buttons: Array = _get_buttons()
	var in_elements: bool = focused in _elements

	# Quetes : liste verticale a gauche, boutons a droite
	if mode == "quests":
		if in_elements:
			var row: int = _elements.find(focused)
			if direction == Vector2.UP and row > 0:
				_elements[row - 1].grab_focus()
			elif direction == Vector2.DOWN and row < _elements.size() - 1:
				_elements[row + 1].grab_focus()
			elif direction == Vector2.RIGHT:
				buttons[0].grab_focus()
			return
		var b: int = buttons.find(focused)
		if b < 0:
			buttons[0].grab_focus()
		elif direction == Vector2.RIGHT and b < buttons.size() - 1:
			buttons[b + 1].grab_focus()
		elif direction == Vector2.LEFT and b > 0:
			buttons[b - 1].grab_focus()
		elif (direction == Vector2.LEFT or direction == Vector2.UP) and not _elements.empty():
			_elements[_selected if _selected >= 0 else 0].grab_focus()
		return

	if in_elements:
		var index: int = _elements.find(focused)
		if direction == Vector2.LEFT and index > 0:
			_elements[index - 1].grab_focus()
		elif direction == Vector2.RIGHT and index < _elements.size() - 1:
			_elements[index + 1].grab_focus()
		elif direction == Vector2.DOWN:
			buttons[0].grab_focus()
		return

	var b_index: int = buttons.find(focused)
	if b_index < 0:
		buttons[0].grab_focus()
		return
	if direction == Vector2.LEFT and b_index > 0:
		buttons[b_index - 1].grab_focus()
	elif direction == Vector2.RIGHT and b_index < buttons.size() - 1:
		buttons[b_index + 1].grab_focus()
	elif direction == Vector2.UP and not _elements.empty():
		var target: int = _selected if _selected >= 0 else 0
		_elements[target].grab_focus()


func _press_focused() -> void :
	var focused: Control = get_focus_owner()
	if focused == null or not focused is BaseButton or focused.disabled:
		return
	focused.emit_signal("pressed")
