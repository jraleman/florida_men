extends RefCounted

## Authored rules and board data shared by the simulation and its views.

const COLORS: Array[Color] = [
	Color("4da3ff"), Color("ff5c6c"), Color("55c47a"), Color("f6c453"),
]
const SPACE_TYPES: Array[int] = [
	0, 2, 1, 3, 1, 4, 1, 5, 1, 2, 3, 1,
	1, 2, 4, 1, 5, 1, 3, 1, 2, 1, 4, 5,
]
const SPACE_NAMES := ["GO", "Boardwalk", "Sunshine", "Puddle", "Bonus", "Detour"]
const SPACE_MARKS := ["GO", ".", "+2", "-2", "+", "-"]
const SPACE_COLORS: Array[Color] = [
	Color("64b778"), Color("457ab7"), Color("f6c453"),
	Color("df6570"), Color("43bcb0"), Color("9b76bb"),
]
const MINI_GAMES: Array[Dictionary] = [
	{"id": "alligator_wrangler", "title": "Alligator Wrangler", "model": "gator",
		"rules": "Move onto the toy gator to wrangle it. It speeds up each time. First to three wins.",
		"controls": "Move in four directions. No action button needed."},
	{"id": "lawnmower_race", "title": "Lawnmower Race", "model": "mower",
		"rules": "Your mower drives itself. Change between three lanes to avoid mud, chairs and chickens. First to the finish wins.",
		"controls": "Left / right changes lane."},
	{"id": "hurricane_party", "title": "Hurricane Party", "model": "party",
		"rules": "Catch ribboned party gifts marked +1. Dodge wooden debris marked -1. Most points in 30 seconds wins.",
		"controls": "Hold left / right to move."},
	{"id": "rocket_man", "title": "Rocket Man", "model": "rocket",
		"rules": "Hold action to rise; release to fall. Fly through the cave gaps. The last pilot flying wins.",
		"controls": "Hold action for thrust. Release to descend."},
	{"id": "flamingo_fiasco", "title": "Flamingo Fiasco", "model": "flamingo",
		"rules": "Chase the toy flamingos and touch them to tag. They scatter, then return to play. Most tags in 30 seconds wins.",
		"controls": "Hold a direction to move. No action button needed."},
	{"id": "python_hunt", "title": "Python Hunt", "model": "python",
		"rules": "Move your marker and place a catch crate. A toy python entering it earns one point. Most catches in 30 seconds wins.",
		"controls": "Move in four directions. Tap action to place a crate."},
]
const CHARACTERS: Array[Dictionary] = [
	{"id": "fm_sunshine", "title": "Sunny", "description": "A sunshine-chasing boardwalk regular."},
	{"id": "fm_dockhand", "title": "Marina", "description": "The marina's unflappable weekend captain."},
	{"id": "fm_tourist", "title": "Flip", "description": "Packed for a holiday. Stayed for the party."},
	{"id": "fm_mechanic", "title": "Sparks", "description": "Keeps every toy mower and rocket running."},
]


## Stable data lookup; unknown games are programming errors, not another game.
static func mini_game(id: String) -> Dictionary:
	for entry in MINI_GAMES:
		if entry["id"] == id:
			return entry
	assert(false, "Unknown Florida Men minigame: " + id)
	return {}
