extends SceneTree

## Real-event four-seat play, a complete six-game party, cosmetics and frozen shares.

const Options = preload("res://games/florida_men/florida_men_options.gd")
const Match = preload("res://games/florida_men/model/party_match.gd")
const Mini = preload("res://games/florida_men/model/mini_game_state.gd")
const Driver = preload("res://games/florida_men/tools/tutorial_driver.gd")
var _failures := PackedStringArray()
var _checks := 0
var _files: Dictionary = {}
var _settings_values: Dictionary = {}
var _save_timer_mode := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _snapshot_progress():
		quit(1)
		return
	GameCatalog.select(Options.GAME_ID)
	var settings := get_root().get_node("Settings")
	_settings_values = (settings.get("_values") as Dictionary).duplicate(true)
	var timer := settings.get("_save_timer") as Timer
	_save_timer_mode = timer.process_mode
	timer.process_mode = Node.PROCESS_MODE_DISABLED
	await _test_four_humans()
	for count in [2, 3]:
		var scene := await _spawn(count)
		var party: RefCounted = scene.get("_match")
		for player in 4:
			_expect(bool(party.call("is_cpu", player)) == (player >= count),
				"Two/three-human setup must fill only its unclaimed seats with CPUs.")
		scene.free()
	await _test_complete_party()
	await _test_previews()
	for key: String in _settings_values:
		settings.call("set_value", key, _settings_values[key])
	timer.stop()
	timer.process_mode = _save_timer_mode
	(get_root().get_node("AchievementManager").get("_toast_queue") as Array).clear()
	get_root().get_node("AudioManager").call("stop_music", 0.0)
	for player: AudioStreamPlayer in get_root().find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.25, true, false, true).timeout
	_restore_progress()
	for failure in _failures:
		printerr(failure)
	print("Florida Men scene: %d checks, %d failures." % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_four_humans() -> void:
	var scene := await _spawn(4)
	var party: RefCounted = scene.get("_match")
	var order: Array[String] = ["alligator_wrangler"]
	party.set("order", order)
	_expect((scene.get("_player_ui") as Array).size() == 4,
		"The actual party scene must create all four shared HUD cards.")
	(scene.get("_advance_button") as Button).grab_focus()
	_key(1, "action", true)
	await process_frame
	_expect(not scene.get("_rolling"), "P2 Enter must not activate P1's focused Roll button.")
	_key(1, "action", false)
	for player in 4:
		_key(player, "action", true)
		await process_frame
		_expect(bool(scene.get("_rolling")), "Every human's own action must roll their die.")
		_key(player, "action", false)
		scene.call("_update_round", 2.0, 0.0)
	_expect(int(party.get("phase")) == Match.Phase.BRIEFING, "All four human turns must reach a briefing.")
	scene.call("_request_action", 3)
	var state: RefCounted = scene.get("_mini")
	_key(3, "left", true)
	await process_frame
	scene.call("_update_round", Mini.STEP, 0.0)
	_key(3, "left", false)
	_expect(state.get("positions")[3] == Vector2(6, 7)
		and state.get("positions")[0] == Vector2.ZERO, "P4's real keypad event must move only P4.")
	var settings := get_root().get_node("Settings")
	settings.call("set_binding_key", "controls/fm_p4_left", KEY_H, Options.GAME_ID)
	var old := InputEventKey.new()
	old.physical_keycode = KEY_KP_4
	old.pressed = true
	Input.parse_input_event(old)
	await process_frame
	scene.call("_update_round", Mini.STEP, 0.0)
	old.pressed = false
	Input.parse_input_event(old)
	_expect(state.get("positions")[3] == Vector2(6, 7), "The old P4 key must stop moving after rebinding.")
	_key(3, "left", true)
	await process_frame
	scene.call("_update_round", Mini.STEP, 0.0)
	_key(3, "left", false)
	_expect(state.get("positions")[3] == Vector2(5, 7), "The rebound P4 key must drive the actual simulation.")
	scene.call("_on_touch_contact", 1, "left")
	scene.call("_on_touch_contact", 2, "action")
	scene.call("_on_touch_contact", 1, "")
	var controls: RefCounted = scene.get("_controls")
	var contacts: Array = controls.call("snapshot")
	_expect(contacts[0]["action"] and contacts[0]["dir"] == Vector2.ZERO,
		"The scene must preserve independent touch action while a direction is released.")
	scene.call("open_pause_menu")
	contacts = controls.call("snapshot")
	_expect(not contacts[0]["action"] and contacts[0]["dir"] == Vector2.ZERO,
		"Opening the actual pause overlay must clear every held input source.")
	var pause: Node = scene.get("_pause_menu")
	if pause != null:
		pause.free()
	paused = false
	scene.free()
	await process_frame


func _test_complete_party() -> void:
	var settings := get_root().get_node("Settings")
	var driver := Driver.new()
	_expect(driver.configure("solo"), "The game-owned tutorial driver must support its declared variant.")
	for key: String in driver.settings_overrides():
		(settings.get("_values") as Dictionary)[key] = driver.settings_overrides()[key]
	var store := get_root().get_node("Store")
	store.call("erase_save", Options.GAME_ID)
	store.call("add_points", Options.GAME_ID, 100)
	_expect(store.call("purchase", Options.GAME_ID, "fm_hat_straw")
		and int(store.call("points", Options.GAME_ID)) == 80, "A real shop purchase must charge its declared price.")
	_expect(store.call("equip", Options.GAME_ID, "fm_hat_straw", "fm_hat_p4"),
		"A bought hat must be wearable by the fourth guest, including a CPU.")
	store.call("equip", Options.GAME_ID, "fm_hat_none", "fm_hat_p1")
	var achievements := get_root().get_node("AchievementManager")
	for id: String in GameCatalog.current().achievements:
		(achievements.get("_unlocked") as Dictionary).erase(id)
	var scene := await _spawn(1)
	driver.start(scene)
	var hats: Array = scene.call("_equipped_hats")
	_expect(hats[3] == "fm_hat_straw" and hats[0] == "fm_hat_none",
		"Actual play must wear independent per-seat outfits.")
	var before := int(store.call("points", Options.GAME_ID))
	var elapsed := 0.0
	var checked_rounds := 0
	var party: RefCounted = scene.get("_match")
	while elapsed < driver.duration() and bool(scene.get("_round_active")):
		driver.update(scene, elapsed, 1.0 / 30.0)
		await process_frame
		if bool(scene.get("_round_active")):
			scene.set("_round_elapsed", elapsed)
			scene.call("_update_round", 1.0 / 30.0, 0.0)
		elapsed += 1.0 / 30.0
		if int(party.get("phase")) == Match.Phase.STANDINGS \
				and int(party.get("round_number")) != checked_rounds:
			_expect(int(store.call("points", Options.GAME_ID)) == before,
				"Board turns and minigame standings must not farm persistent shop currency.")
			checked_rounds = int(party.get("round_number"))
	driver.update(scene, elapsed, 0.0)
	_expect(driver.validate_finished(scene), "Real keyboard steering must complete all six distinct minigames.")
	print("Complete real-input party took %.2f model seconds." % elapsed)
	_expect(int(store.call("points", Options.GAME_ID)) == before + int(party.call("payout")),
		"The actual shared results must bank exactly one completed-party payout.")
	_expect(bool(achievements.call("is_unlocked", "fm_first_party")),
		"A genuine completed party must unlock its completion achievement.")
	for condition in [
		["fm_three_wins", party.get("wins")[0] >= 3],
		["fm_forty_coins", party.get("coins")[0] >= 40],
		["fm_champion", (party.call("winners") as Array).has(0)],
	]:
		_expect(bool(achievements.call("is_unlocked", condition[0])) == condition[1],
			"The actual party must unlock conditional achievements only when earned.")
	var ui: Array = scene.get("_player_ui")
	for player in 4:
		_expect((ui[player]["result_score"] as Label).text == str(party.get("coins")[player]),
			"Every human/CPU coin total must reach its shared result card.")
	_expect((ui[3]["caption"] as Label).text == "CPU4"
		and (ui[3]["caption"] as Label).accessibility_description == "CPU 4",
		"The shared fourth card must describe its real controller, not claim another human.")
	var payload: Dictionary = scene.call("_share_payload")
	_expect(payload["score_values"] == party.get("coins")
		and payload["fm_standings"].size() == 4 and payload["fm_hats"][3] == "fm_hat_straw",
		"Shared results must freeze all four scores, standings and actual outfits.")
	store.call("purchase", Options.GAME_ID, "fm_hat_rain")
	store.call("equip", Options.GAME_ID, "fm_hat_rain", "fm_hat_p4")
	var unchanged: Dictionary = scene.call("_share_payload")
	_expect(unchanged["fm_hats"][3] == "fm_hat_straw", "A later shop change cannot rewrite a finished share portrait.")
	var art := (load(GameCatalog.current().share_art_scene_path) as PackedScene).instantiate()
	art.call("configure", payload)
	get_root().add_child(art)
	await process_frame
	_expect(art.get("_world") != null, "The frozen share must instantiate the real original 3D art.")
	art.free()
	var wallet_after_shopping := int(store.call("points", Options.GAME_ID))
	scene.call("_on_play_again_pressed")
	_expect(scene.get("_scores") == [10, 10, 10, 10]
		and (party.get("history") as Array).is_empty(), "Replay must reset all four board seats and the party history.")
	_expect(int(store.call("points", Options.GAME_ID)) == wallet_after_shopping,
		"Replay itself must never pay shop currency.")
	scene.free()
	await process_frame


func _test_previews() -> void:
	var manifest := GameCatalog.current()
	var bare_meshes := 0
	for item in manifest.store_items:
		var stage := (load(manifest.store_preview_scene_path) as PackedScene).instantiate()
		stage.call("configure", item)
		get_root().add_child(stage)
		var world: Control = stage.get("_world")
		var meshes := (world.get("_content") as Node3D).find_children("*", "MeshInstance3D", true, false)
		if int(item.get("price", 0)) == 0:
			bare_meshes = meshes.size()
		else:
			_expect(meshes.size() > bare_meshes,
				"Every paid store preview must actually add its hat geometry to the shared guest.")
		stage.free()
	for entry in manifest.gallery_exhibits:
		var stage := (load(manifest.gallery_stage_scene_path) as PackedScene).instantiate()
		get_root().add_child(stage)
		stage.call("configure", entry)
		stage.call("set_view", 0.2, 0.1, 1.1)
		stage.call("set_auto_spin", false)
		var world: Control = stage.get("_world")
		var viewport: SubViewport = world.get("viewport")
		_expect(viewport.own_world_3d and viewport.world_3d != get_root().world_3d,
			"Every gallery exhibit must own an isolated original 3D world.")
		_expect(not (world.get("_content") as Node3D).find_children("*", "MeshInstance3D", true, false).is_empty(),
			"Every declared gallery exhibit must contain actual mesh geometry.")
		stage.free()
	await process_frame


func _spawn(humans: int) -> Node:
	var session := get_root().get_node("GameSession")
	if humans == 1:
		session.call("configure_single_player")
	else:
		session.call("configure_multiplayer", 0, 1, humans)
	var scene := (load(GameCatalog.current_gameplay_scene_path()) as PackedScene).instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	return scene


func _key(player: int, verb: String, pressed: bool) -> void:
	for source in InputMap.action_get_events(Options.action(player, verb)):
		if source is InputEventKey:
			var event := source.duplicate() as InputEventKey
			event.pressed = pressed
			event.echo = false
			Input.parse_input_event(event)
			return
	assert(false, "Missing Florida Men key binding.")


func _snapshot_progress() -> bool:
	for path in ["user://store.cfg", "user://achievements.cfg"]:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				printerr("Cannot back up progress before scene tests: " + path)
				return false
			_files[path] = file.get_buffer(file.get_length())
		else:
			_files[path] = null
	return true


func _restore_progress() -> void:
	for path: String in _files:
		if _files[path] == null:
			if FileAccess.file_exists(path):
				_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
					"Scene tests must remove only their newly created save file.")
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_expect(false, "Cannot restore the original progress file: " + path)
			else:
				file.store_buffer(_files[path])


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
