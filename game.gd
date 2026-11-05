extends RefCounted

## Catalog data only; the framework never branches on this game's name.

const Options = preload("res://games/florida_men/florida_men_options.gd")
const Data = preload("res://games/florida_men/data/party_data.gd")


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Florida Men"
	game.tagline = "Six headlines. Four guests. One very strange holiday."
	game.menu_order = 18
	game.gameplay_scene_path = Options.ROOT + "gameplay.tscn"
	game.intro_scene_path = Options.ROOT + "intro.tscn"
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.max_local_players = 4
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.characters = Data.CHARACTERS.duplicate(true)
	game.character_preview_scene_path = Options.ROOT + "presentation/character_preview.tscn"
	game.tunables = Options.TUNABLES
	game.solo_setup_choices = [Options.ROUNDS_KEY, Options.CPU_KEY]
	game.control_bindings = Options.CONTROL_BINDINGS
	game.store_items = Options.STORE_ITEMS
	game.store_slots = Options.STORE_SLOTS
	game.store_currency = Options.STORE_CURRENCY
	game.store_preview_scene_path = Options.ROOT + "presentation/store_preview.tscn"
	game.gallery_exhibits = Options.GALLERY_EXHIBITS
	game.gallery_stage_scene_path = Options.ROOT + "presentation/gallery_stage.tscn"
	game.share_art_scene_path = Options.ROOT + "presentation/share_art.tscn"
	game.stats_url = "https://deskcansaw.com"
	game.tutorial_video_path = Options.ROOT + "assets/video/tutorial.ogv"
	game.tutorial_poster_path = Options.ROOT + "assets/video/tutorial_poster.webp"
	game.achievements = {
		"fm_first_party": {"title": "Weekend Regular", "description": "Complete a whole party.", "badge": "SUN"},
		"fm_three_wins": {"title": "Headline Act", "description": "A human wins three minigames in one party.", "badge": "3X"},
		"fm_forty_coins": {"title": "Pocketful of Sunshine", "description": "A human finishes with at least 40 board coins.", "badge": "40"},
		"fm_champion": {"title": "Florida Famous", "description": "A human wins the party, including a shared win.", "badge": "WIN"},
	}
	game.copy = {
		"character_label": "Holiday guest",
		"single_player_description": "One human and three CPU guests share the board and all six minigames.",
		"multiplayer_description": "Two to four local humans play together. CPU guests fill the remaining seats.",
		"solo_confirm_title": "Pack for a strange holiday",
		"solo_confirm_description": "%s. Unclaimed seats are CPU guests; touch controls drive Player 1.",
		"versus_confirm_title": "Bring your party",
		"versus_confirm_description": "Choose two, three or four humans. Every party has four guests. Round count and CPU reactions are in Settings > Game.",
		"player_one_control_description": "Move, roll, hold rocket thrust and place catch crates.",
		"player_two_control_description": "Use your own movement and action keys.",
		"player_three_control_description": "Use your own movement and action keys.",
		"player_four_control_description": "Use your own movement and action keys, including rebound number-pad keys.",
		"instructions_headline": "Most coins wins the holiday",
		"instructions_rules": "Start with 10 coins. Everyone rolls, then one headline game plays. Placement pays 5 / 3 / 1 / 0 coins and 3 / 2 / 1 / 0 points. Coins decide the party; wins break a tie. Equal minigame metrics share their placement.",
		"instructions_solo_summary": "Player 1 faces three rule-aware CPU guests. Roll on the 24-space board, read each player-paced briefing, then play its minigame. The party ends after the selected number of minigames, not the shell's timer or lives. Sunshine Tokens are paid only for a completed party; they buy cosmetic hats, not dice luck or power. This is an offline toy game, not real wildlife or storm-safety advice.",
		"instructions_versus_summary": "Two to four humans play minigames simultaneously on this device. Board turns follow P1 / P2 / P3 / P4; CPU guests fill unclaimed seats. Keyboard and assigned gamepads work for every human. Mobile is solo with three CPUs.",
		"instructions_player_one_controls": "Move with your keys, left stick or D-pad; action is also gamepad A. Solo has independent on-screen direction/action contacts.",
		"instructions_player_two_controls": "Your own movement keys; assigned gamepad stick/D-pad and A also work.",
		"instructions_player_three_controls": "Your own movement keys; assigned gamepad stick/D-pad and A also work.",
		"instructions_player_four_controls": "Your own movement keys; assigned gamepad stick/D-pad and A also work.",
	}
	var rules := PackedStringArray()
	for mini in Data.MINI_GAMES:
		rules.append("%s: %s %s" % [mini["title"], mini["rules"], mini["controls"]])
	game.copy["instructions_solo_summary"] += "\n\n" + "\n\n".join(rules)
	game.copy["instructions_versus_summary"] += "\n\n" + "\n\n".join(rules)
	var theme := GameTheme.new()
	theme.logo_texture_path = Options.ROOT + "assets/game-icon.svg"
	theme.accent = Color("f6c453")
	theme.logo_color = Color.WHITE
	theme.plaque_color = Color("163e47")
	theme.light = Color("fff3d4")
	theme.background_top = Color("204e58")
	theme.background_bottom = Color("102b38")
	theme.style_share_card = true
	game.theme = theme
	game.credits = [
		{"heading": "Florida Men", "lines": ["An original offline toy-board party by DeskCanSaw Games"]},
		{"heading": "Art & Sound", "lines": [
			"Original procedural 3D guests, wildlife toys, props and boardwalk scenery",
			"Original synthesized holiday music and game cues",
		]},
	]
	return game
