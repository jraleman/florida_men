extends RefCounted

## Constants-only declarations: settings, keyboard bindings and the souvenir shop.

const GAME_ID := "florida_men"
const ROOT := "res://games/florida_men/"
const ROUNDS_KEY := "game/fm_rounds"
const CPU_KEY := "game/fm_cpu"
const TUNABLES: Array[Dictionary] = [
	{"key": ROUNDS_KEY, "type": GameManifest.OPTION_CHOICE, "default": 10,
		"title": "Minigames per party", "heading": "Next party",
		"description": "Each minigame follows one board turn per seat. Coins decide the party; wins break a tie.",
		"choices": [
			{"value": 5, "title": "5 - quick"},
			{"value": 6, "title": "6 - all games"},
			{"value": 10, "title": "10 - classic"},
			{"value": 20, "title": "20 - long"},
			{"value": 30, "title": "30 - extended"},
		]},
	{"key": CPU_KEY, "type": GameManifest.OPTION_CHOICE, "default": 1,
		"title": "CPU guests", "heading": "Next party",
		"description": "Unused seats are CPU guests. This changes their reaction time, not their rules or rewards.",
		"choices": [
			{"value": 0, "title": "Relaxed"},
			{"value": 1, "title": "Everyday"},
			{"value": 2, "title": "Spry"},
		]},
]
const CONTROL_BINDINGS: Array[Dictionary] = [
	{"key": "controls/fm_p1_up", "action": &"fm_p1_up", "default": KEY_W,
		"title": "Up", "player": 0, "movement": true, "heading": "Player 1"},
	{"key": "controls/fm_p1_down", "action": &"fm_p1_down", "default": KEY_S,
		"title": "Down", "player": 0, "movement": true, "heading": "Player 1"},
	{"key": "controls/fm_p1_left", "action": &"fm_p1_left", "default": KEY_A,
		"title": "Left", "player": 0, "movement": true, "heading": "Player 1"},
	{"key": "controls/fm_p1_right", "action": &"fm_p1_right", "default": KEY_D,
		"title": "Right", "player": 0, "movement": true, "heading": "Player 1"},
	{"key": "controls/fm_p1_action", "action": &"fm_p1_action", "default": KEY_SPACE,
		"title": "Roll / thrust / crate", "player": 0, "heading": "Player 1"},
	{"key": "controls/fm_p2_up", "action": &"fm_p2_up", "default": KEY_UP,
		"title": "Up", "player": 1, "movement": true, "heading": "Player 2"},
	{"key": "controls/fm_p2_down", "action": &"fm_p2_down", "default": KEY_DOWN,
		"title": "Down", "player": 1, "movement": true, "heading": "Player 2"},
	{"key": "controls/fm_p2_left", "action": &"fm_p2_left", "default": KEY_LEFT,
		"title": "Left", "player": 1, "movement": true, "heading": "Player 2"},
	{"key": "controls/fm_p2_right", "action": &"fm_p2_right", "default": KEY_RIGHT,
		"title": "Right", "player": 1, "movement": true, "heading": "Player 2"},
	{"key": "controls/fm_p2_action", "action": &"fm_p2_action", "default": KEY_ENTER,
		"title": "Roll / thrust / crate", "player": 1, "heading": "Player 2"},
	{"key": "controls/fm_p3_up", "action": &"fm_p3_up", "default": KEY_I,
		"title": "Up", "player": 2, "movement": true, "heading": "Player 3"},
	{"key": "controls/fm_p3_down", "action": &"fm_p3_down", "default": KEY_K,
		"title": "Down", "player": 2, "movement": true, "heading": "Player 3"},
	{"key": "controls/fm_p3_left", "action": &"fm_p3_left", "default": KEY_J,
		"title": "Left", "player": 2, "movement": true, "heading": "Player 3"},
	{"key": "controls/fm_p3_right", "action": &"fm_p3_right", "default": KEY_L,
		"title": "Right", "player": 2, "movement": true, "heading": "Player 3"},
	{"key": "controls/fm_p3_action", "action": &"fm_p3_action", "default": KEY_U,
		"title": "Roll / thrust / crate", "player": 2, "heading": "Player 3"},
	{"key": "controls/fm_p4_up", "action": &"fm_p4_up", "default": KEY_KP_8,
		"title": "Up", "player": 3, "movement": true, "heading": "Player 4"},
	{"key": "controls/fm_p4_down", "action": &"fm_p4_down", "default": KEY_KP_2,
		"title": "Down", "player": 3, "movement": true, "heading": "Player 4"},
	{"key": "controls/fm_p4_left", "action": &"fm_p4_left", "default": KEY_KP_4,
		"title": "Left", "player": 3, "movement": true, "heading": "Player 4"},
	{"key": "controls/fm_p4_right", "action": &"fm_p4_right", "default": KEY_KP_6,
		"title": "Right", "player": 3, "movement": true, "heading": "Player 4"},
	{"key": "controls/fm_p4_action", "action": &"fm_p4_action", "default": KEY_KP_0,
		"title": "Roll / thrust / crate", "player": 3, "heading": "Player 4"},
]
## Match completion is the only payout authority; the generic score policy pays zero.
const STORE_CURRENCY := {
	"name": "Sunshine Token", "plural": "Sunshine Tokens",
	"points_per_score": 0.0, "round_bonus": 0, "win_bonus": 0, "max_per_round": 0,
}
const STORE_SLOTS: Array[Dictionary] = [
	{"id": "fm_hat_p1", "kind": "fm_hat", "title": "P1"},
	{"id": "fm_hat_p2", "kind": "fm_hat", "title": "P2"},
	{"id": "fm_hat_p3", "kind": "fm_hat", "title": "P3"},
	{"id": "fm_hat_p4", "kind": "fm_hat", "title": "P4"},
]
const STORE_ITEMS: Array[Dictionary] = [
	{"id": "fm_hat_none", "kind": "fm_hat", "default": true, "price": 0,
		"title": "Sea Breeze", "description": "The original bare-headed holiday look.",
		"badge": "BARE", "color": Color("71c5be"), "heading": "Boardwalk hats"},
	{"id": "fm_hat_straw", "kind": "fm_hat", "price": 20,
		"title": "Sun Hat", "description": "A broad straw brim with your seat's ribbon.",
		"badge": "SUN", "color": Color("e4bd76"), "heading": "Boardwalk hats"},
	{"id": "fm_hat_party", "kind": "fm_hat", "price": 35,
		"title": "Party Cone", "description": "A striped cone for a very serious party.",
		"badge": "PARTY", "color": Color("ee82ad"), "heading": "Boardwalk hats"},
	{"id": "fm_hat_rain", "kind": "fm_hat", "price": 50,
		"title": "Rain Hat", "description": "A yellow bucket hat for toy-weather adventures.",
		"badge": "RAIN", "color": Color("f6c453"), "heading": "Boardwalk hats"},
	{"id": "fm_hat_propeller", "kind": "fm_hat", "price": 70,
		"title": "Propeller Cap", "description": "Decorative blades. Absolutely no extra rocket thrust.",
		"badge": "SPIN", "color": Color("6dc9db"), "heading": "Boardwalk hats"},
]
const GALLERY_EXHIBITS: Array[Dictionary] = [
	{"id": "fm_board", "model": "board", "title": "Sunshine Boardwalk",
		"description": "The actual 24-space party board. Marks identify every tile's coin effect.",
		"heading": "The party", "badge": "24", "facts": ["24 spaces", "Four seats", "Original toy scenery"]},
	{"id": "fm_crew", "model": "crew", "title": "Weekend Regular",
		"description": "The same original holiday guest used on the board and in minigames.",
		"heading": "The party", "badge": "P1"},
	{"id": "fm_gator", "model": "gator", "title": "Convenience-store Gator",
		"description": "A smiling wooden toy, not wildlife-handling advice.",
		"heading": "Six headlines", "badge": "GTR"},
	{"id": "fm_mower", "model": "mower", "title": "Weekend Mower",
		"description": "Four wheels, three lanes and a very determined holiday driver.",
		"heading": "Six headlines", "badge": "MOW"},
	{"id": "fm_party", "model": "party", "title": "Party Forecast",
		"description": "Ribboned +1 gifts and wooden -1 debris have different shapes and labels.",
		"heading": "Six headlines", "badge": "+/-"},
	{"id": "fm_rocket", "model": "rocket", "title": "Backyard Toy Rocket",
		"description": "A fanciful tin rocket with a seated pilot and an entirely imaginary engine.",
		"heading": "Six headlines", "badge": "FLY"},
	{"id": "fm_flamingo", "model": "flamingo", "title": "Garden Flamingo",
		"description": "Long legs, a curved neck and a talent for scattering.",
		"heading": "Six headlines", "badge": "TAG"},
	{"id": "fm_python", "model": "python", "title": "Marsh Python",
		"description": "A coiled green toy with bright eyes; catch crates return it safely to the toy box.",
		"heading": "Six headlines", "badge": "SSS"},
]


## Each seat's action names remain stable even when its keys are rebound.
static func action(player: int, verb: String) -> StringName:
	return StringName("fm_p%d_%s" % [player + 1, verb])
