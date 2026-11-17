extends RefCounted

## An improbable postcard starring the actual party's gator, mower and flamingo.
const Helpers = preload("res://tools/cover_art_helpers.gd")
const Models = preload("res://games/florida_men/world/toy_models.gd")
const Data = preload("res://games/florida_men/data/party_data.gd")


## Seafoam, tangerine and big postcard lettering, not another palm-tree app icon.
static func design() -> Dictionary:
	return {
		"paper": Color("b2e4d3"), "ink": Color("24545b"), "accent": Color("ed9764"),
		"motif": "confetti", "camera": Vector3(22, 17, -7),
		"photo": Rect2(-12, 285, 1048, 630),
		"lettering": [
			{"text": "FLORIDA", "at": Vector2(50, 171), "size": 183, "font": "round"},
			{"text": "MEN", "at": Vector2(57, 351), "size": 215},
			{"text": "A VERY FLORIDA PARTY.", "at": Vector2(57, 978), "size": 39, "font": "round"},
		],
	}


## Staging adds no minigame, character costume or live player data.
static func build(parent: Node) -> Node:
	var root := Helpers.group(parent)
	Helpers.place(root, Models.gator(), Vector3(-0.5, 0, 0.9),
		Vector3(0, -35, 0), 1.35)
	Helpers.place(root, Models.mower(Data.COLORS[0], "fm_hat_none", 0),
		Vector3(1.0, 0.4, -0.6), Vector3(0, -20, -8), 1.15)
	Helpers.place(root, Models.flamingo(), Vector3(-1.1, 0.4, -0.8),
		Vector3(0, 10, 0), 0.7)
	return root
