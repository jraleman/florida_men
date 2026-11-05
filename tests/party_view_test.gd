extends SceneTree

## Window-required rendering and phone/landscape/ultrawide framing checks.

const Data = preload("res://games/florida_men/data/party_data.gd")
const Mini = preload("res://games/florida_men/model/mini_game_state.gd")
const Match = preload("res://games/florida_men/model/party_match.gd")
var _failures := PackedStringArray()
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("party_view_test.gd requires a real Compatibility graphics window.")
		quit(1)
		return
	GameCatalog.select("florida_men")
	get_root().get_node("GameSession").call("configure_multiplayer", 0, 1, 4)
	var game := (load(GameCatalog.current_gameplay_scene_path()) as PackedScene).instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var world: Control = game.get("_world")
	var viewport: SubViewport = world.get("viewport")
	var camera: Camera3D = world.get("camera")
	var party: RefCounted = game.get("_match")
	var artifact_dir := _artifact_directory()
	var commands: Array[Dictionary] = []
	for player in 4:
		commands.append({"dir": Vector2.ZERO, "action": false})
	for window_size in [
		Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390), Vector2i(2560, 1080),
	]:
		get_root().size = window_size
		await process_frame
		await process_frame
		(game.get("_touch") as Control).visible = window_size.y > window_size.x
		party.set("phase", Match.Phase.BOARD)
		world.call("show_board")
		world.call("sync_board", party, {}, 1.0)
		game.call("_refresh_phase")
		await process_frame
		await RenderingServer.frame_post_draw
		if not artifact_dir.is_empty() and window_size == Vector2i(1280, 720):
			_expect(get_root().get_texture().get_image().save_png(
				artifact_dir.path_join("board-layout.png")) == OK, "Board capture must save.")
		for entry in Data.MINI_GAMES:
			var state := Mini.new()
			state.configure(entry["id"], 529, [true, true, true, true])
			for tick in 60:
				state.step(1.0 / 30.0, commands)
			party.set("phase", Match.Phase.MINIGAME)
			var order: Array[String] = [entry["id"]]
			party.set("order", order)
			game.set("_mini", state)
			game.call("_refresh_phase")
			world.call("show_minigame", entry["id"])
			world.call("sync_minigame", state)
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(world.size.x > 0 and world.size.y > 0
				and world.position.y + world.size.y <= (game.get("_party_panel") as Control).position.y,
				"%s must leave real play space clear of its own briefing." % entry["title"])
			_expect(viewport.own_world_3d and viewport.world_3d != get_root().world_3d,
				"Every minigame must remain in an isolated 3D world.")
			for actor: Node3D in world.get("_actors"):
				var point := camera.unproject_position(actor.global_position + Vector3(0, 0.5, 0))
				_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(point),
					"%s must frame all four actual player models at %s." % [entry["title"], window_size])
			for ui: Dictionary in game.get("_player_ui"):
				var card: Control = ui["card"]
				_expect(get_root().get_visible_rect().encloses(card.get_global_rect()),
					"Score card %s must fit %s: %s inside %s." % [
						card.name, window_size, card.get_global_rect(), get_root().get_visible_rect(),
					])
			var image := viewport.get_texture().get_image()
			_expect(_has_geometry(image), "%s must render real geometry, not only a clear color." % entry["title"])
			if window_size == Vector2i(1280, 720) and not artifact_dir.is_empty():
				_expect(image.save_png(artifact_dir.path_join(entry["id"] + ".png")) == OK,
					"A requested review capture must save successfully.")
		if not artifact_dir.is_empty() and window_size == Vector2i(390, 844):
			var full := get_root().get_texture().get_image()
			_expect(full.save_png(artifact_dir.path_join("portrait.png")) == OK, "Portrait review capture must save.")
	await _test_results(game, artifact_dir)
	game.free()
	await process_frame
	get_root().get_node("AudioManager").call("stop_music", 0.0)
	for player: AudioStreamPlayer in get_root().find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.25, true, false, true).timeout
	for failure in _failures:
		printerr(failure)
	print("Florida Men rendering: %d checks, %d failures." % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_results(game: Node, artifact_dir: String) -> void:
	var party: RefCounted = game.get("_match")
	party.call("configure", 4, 30, 123)
	game.set("_rounds", 30)
	var metrics: Array[float] = [3.0, 2.0, 1.0, 0.0]
	for round_index in 30:
		for player in 4:
			party.call("roll")
			party.call("finish_board_turn")
		party.call("start_minigame")
		party.call("finish_minigame", metrics)
		party.call("advance")
	game.call("_sync_scores")
	game.call("_finish_round")
	var achievements: Array = game.get("_round_achievements")
	for achievement: Dictionary in GameCatalog.current().achievements.values():
		achievements.append(achievement.duplicate(true))
	game.set("_round_active", false)
	var outcome: Dictionary = game.call("_describe_round_outcome", 0, 0)
	(game.get("_result_label") as Label).text = outcome["result"]
	(game.get("_round_subtitle") as Label).text = outcome["subtitle"]
	(game.get("_round_highlight") as Label).text = game.call("_round_highlight_summary")
	for player in 4:
		(game.get("_player_ui")[player]["result_score"] as Label).text = str(party.get("coins")[player])
	game.call("_populate_score_screen", outcome["result"], outcome["color"])
	var payload: Dictionary = game.call("_share_payload")
	var rendered: Dictionary = await get_root().get_node("ShareManager").call("preview_score_image", payload)
	_expect(bool(rendered.get("ok", false)), "The actual shared 1200x630 card must render all four frozen guests.")
	if bool(rendered.get("ok", false)):
		var texture := rendered["texture"] as Texture2D
		(game.get("_share_card_preview") as TextureRect).texture = texture
		(game.get("_share_card_preview") as Control).show()
		(game.get("_share_placeholder") as Control).hide()
		if not artifact_dir.is_empty():
			_expect(texture.get_image().save_png(artifact_dir.path_join("share.png")) == OK,
				"Share review capture must save.")
	(game.get("_round_over") as Control).show()
	for window_size in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]:
		get_root().size = window_size
		for mode in ["results", "stats"]:
			var round_panel := game.get("_round_panel") as Control
			var score_panel := game.get("_score_panel") as Control
			round_panel.visible = mode == "results"
			score_panel.visible = mode == "stats"
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var panel := round_panel if mode == "results" else score_panel
			var scroll := game.get("_results_scroll") as ScrollContainer
			_expect(get_root().get_visible_rect().encloses(scroll.get_global_rect())
				and panel.size.x <= scroll.size.x + 1,
				"%s must fit horizontally and scroll vertically at %s: %s inside %s." % [
					mode, window_size, panel.get_global_rect(), scroll.get_global_rect(),
				])
			if panel.size.y > scroll.size.y:
				scroll.scroll_vertical = ceili(scroll.get_v_scroll_bar().max_value)
				await process_frame
				await RenderingServer.frame_post_draw
				var button := game.get("_see_score_button" if mode == "results"
					else "_back_to_results_button") as Control
				_expect(scroll.get_global_rect().encloses(button.get_global_rect()),
					"Scrolling %s must reveal its footer at %s: %s inside %s." % [
						mode, window_size, button.get_global_rect(), scroll.get_global_rect(),
					])
				if not artifact_dir.is_empty():
					_expect(get_root().get_texture().get_image().save_png(artifact_dir.path_join(
						"%s-%dx%d-bottom.png" % [mode, window_size.x, window_size.y])) == OK,
						"Scrolled footer review captures must save.")
				scroll.scroll_vertical = 0
				await process_frame
				await RenderingServer.frame_post_draw
			if not artifact_dir.is_empty():
				_expect(get_root().get_texture().get_image().save_png(artifact_dir.path_join(
					"%s-%dx%d.png" % [mode, window_size.x, window_size.y])) == OK,
					"Results/statistics review captures must save.")
	get_root().size = Vector2i(1280, 720)
	(game.get("_round_panel") as Control).show()
	(game.get("_score_panel") as Control).hide()
	game.call("_set_capture_inset", 275.0)
	var actions := (game.get("_play_again_button") as Button).get_parent()
	(actions.get_child(actions.get_child_count() - 1) as Button).grab_focus()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var available := get_root().get_visible_rect()
	available.size.y -= 275.0
	var scroll := game.get("_results_scroll") as ScrollContainer
	_expect(available.encloses(scroll.get_global_rect()),
		"Recorded results must not draw under the reserved tutorial caption.")
	_expect(scroll.get_global_rect().encloses(
		(game.get("_result_label") as Control).get_global_rect()),
		"Recorded results must retain their winner heading even when a footer gains focus.")
	_expect(scroll.get_global_rect().encloses(
		(game.get("_play_again_button") as Control).get_global_rect()),
		"Recorded results must keep their primary action visible.")
	if not artifact_dir.is_empty():
		_expect(get_root().get_texture().get_image().save_png(artifact_dir.path_join(
			"tutorial-results-layout.png")) == OK, "Tutorial results review capture must save.")
	game.call("_set_capture_inset", 0.0)


func _has_geometry(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var background := image.get_pixel(0, 0)
	var geometry := 0
	var samples := 0
	for y in range(0, image.get_height(), maxi(1, image.get_height() / 64)):
		for x in range(0, image.get_width(), maxi(1, image.get_width() / 64)):
			samples += 1
			var pixel := image.get_pixel(x, y)
			if Vector3(pixel.r, pixel.g, pixel.b).distance_to(
					Vector3(background.r, background.g, background.b)) > 0.08:
				geometry += 1
	return geometry > samples * 0.025


func _artifact_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			var directory := argument.trim_prefix("--capture-dir=")
			var error := DirAccess.make_dir_recursive_absolute(directory)
			_expect(error == OK, "Could not create the explicitly requested capture directory.")
			return directory
	return ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
