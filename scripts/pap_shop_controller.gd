extends Node

# Magasin (solo ET coop) : un compteur de jetons Pack-a-Punch a cote du
# compteur de pieces meca. Visible des qu'on a au moins un jeton.
#
# Passe par _get_meca_parts_ui(player_index), qui existe a la fois dans
# shop.gd (solo) et coop_shop.gd (coop).

var _shop = null
var _player_count: = 0

var _counters: = []        # HBoxContainer (copie de MecaPartsUI)
var _counter_labels: = []


func setup(shop) -> void :
	_shop = shop
	_player_count = RunData.get_player_count()

	for player_index in _player_count:
		_setup_counter(player_index)
		_refresh_counter(player_index)

	var _e = RunData.connect("tinkiluz_pap_tokens_changed", self, "_on_pap_tokens_changed")


func _setup_counter(player_index: int) -> void :
	var meca_ui: Control = _shop._get_meca_parts_ui(player_index)

	if meca_ui == null:
		_counters.push_back(null)
		_counter_labels.push_back(null)
		return

	# Copie sans les signaux ni le script : juste l'icone et le texte
	var counter: HBoxContainer = HBoxContainer.new()
	counter.name = "TinkiluzPapTokensUI"
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.focus_mode = Control.FOCUS_NONE
	counter.add_constant_override("separation", meca_ui.get_constant("separation"))
	counter.size_flags_vertical = meca_ui.size_flags_vertical

	var label: Label = null

	for child in meca_ui.get_children():
		var copy: Node = child.duplicate(Node.DUPLICATE_GROUPS)
		if copy is Control:
			copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if copy is TextureRect:
			copy.texture = RunData.tinkiluz_get_token_texture()
			copy.expand = true
			copy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			copy.rect_min_size = Vector2(56, 56)
			copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif copy is Label:
			copy.set_script(null)
			label = copy
		counter.add_child(copy)

	meca_ui.get_parent().add_child_below_node(meca_ui, counter)

	_counters.push_back(counter)
	_counter_labels.push_back(label)


func _refresh_counter(player_index: int) -> void :
	var counter = _counters[player_index]
	if counter == null:
		return

	var tokens: int = RunData.tinkiluz_get_pap_tokens(player_index)
	counter.visible = tokens > 0

	var label = _counter_labels[player_index]
	if label != null:
		label.text = str(tokens)


func _on_pap_tokens_changed(_new_value: int, player_index: int) -> void :
	if player_index < _player_count:
		_refresh_counter(player_index)
