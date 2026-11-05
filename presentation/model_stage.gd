extends Control

## Shared presentation adapter; share portraits use frozen ids, never live outfits.

const World = preload("res://games/florida_men/world/party_world.gd")
const Data = preload("res://games/florida_men/data/party_data.gd")
const Options = preload("res://games/florida_men/florida_men_options.gd")
@export_enum("character", "store", "gallery", "share") var presentation := "character"
var _data: Dictionary = {}
var _world: Control
var _auto_spin := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = World.new()
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_world)
	var store := get_tree().root.get_node_or_null("Store")
	if store != null and presentation == "character":
		store.connect("equipped_changed", _on_equipped_changed)
	_apply()


## Can be configured before entering the scene tree, like other framework previews.
func configure(data: Dictionary) -> void:
	_data = data.duplicate(true)
	if is_node_ready():
		_apply()


## The shared viewer owns the interaction and reduced-motion policy.
func set_view(yaw: float, pitch: float, zoom: float) -> void:
	if _world != null:
		_world.call("set_view", yaw, pitch, zoom)


func set_auto_spin(enabled: bool) -> void:
	_auto_spin = enabled
	if _world != null:
		_world.call("set_auto_spin", enabled)


func _apply() -> void:
	match presentation:
		"gallery":
			_world.call("show_exhibit", str(_data.get("model", "crew")))
		"store":
			_world.call("show_exhibit", "crew", Data.COLORS[0],
				str(_data.get("id", "fm_hat_none")), 0)
		"share":
			var hats: Array[String] = []
			var characters: Array[int] = []
			hats.assign(_data.get("fm_hats",
				["fm_hat_none", "fm_hat_none", "fm_hat_none", "fm_hat_none"]))
			characters.assign(_data.get("fm_characters", [0, 1, 2, 3]))
			_world.call("show_portrait", hats, characters)
		_:
			var player := int(_data.get("player_index", 0))
			var character := 0
			for index in Data.CHARACTERS.size():
				if Data.CHARACTERS[index]["id"] == _data.get("id", ""):
					character = index
			var hat := "fm_hat_none"
			var store := get_tree().root.get_node_or_null("Store")
			if store != null:
				hat = str(store.call("equipped_id", Options.GAME_ID, "fm_hat_p%d" % (player + 1)))
			_world.call("show_exhibit", "crew",
				_data.get("player_color", Data.COLORS[player]), hat, character)
	_world.call("set_auto_spin", _auto_spin)


func _on_equipped_changed(game: String, _slot: String, _item: String) -> void:
	if game == Options.GAME_ID:
		_apply()
