# FloridaMen — Development Plan

### Phase 1: Core Game Flow

Set up the scene tree and global state that everything else builds on.

**Scene structure:**
```
Main (autoload)
├── MainMenu
├── LobbyScreen
├── MiniGameSelector
├── MiniGame (base scene, swapped per game)
└── ScoreBoard
```

**Global state (autoload singleton):**
- Player registry: up to 4 players, each with a name, score, and input device
- Session state: current mini-game, round number, scores
- Transitions: `change_scene_to(scene, data)` wrapper that passes context between screens

---

### Phase 2: Menu & Lobby Flow

**MainMenu → LobbyScreen → MiniGameSelector → MiniGame → ScoreBoard → (loop)**

- **MainMenu:** "Play" / "Quit" — nothing fancy
- **LobbyScreen:** Players press a button to join (keyboard or gamepad). Locks in when host presses "Start". Supports 1–4 players.
- **MiniGameSelector:** Randomly picks the next mini-game (or rotates through all 6 before repeating). Shows name + brief rule text.
- **ScoreBoard:** Shown after each mini-game. Displays round winner and cumulative points. After N rounds, shows overall winner and returns to lobby.

---

### Phase 3: Mini-Game Base Framework

Every mini-game inherits from a common `MiniGame` base scene:

```gdscript
class_name MiniGame extends Node

signal game_over(results: Array)  # [{player_id, score}]

var time_limit: float = 60.0
var players: Array  # injected by session manager

func _ready():
    setup()
    start_timer()

func setup(): pass      # override per game
func on_timeout(): pass # override or emit game_over with current scores
```

The session manager listens for `game_over`, updates global scores, then transitions to ScoreBoard.

---

### Phase 4: Mini-Game Logic

Each mini-game is one scene that overrides `setup()` and drives its own loop.

#### 1. Alligator Wrangler
- An alligator moves around a grid randomly on a timer
- Players move a cursor trying to land on the same cell as the gator
- First player to "wrangle" (overlap) N times wins
- Gator speed increases each successful wrangle

#### 2. Lawnmower Race
- Top-down, players drive lawnmowers from A to B
- Obstacle tiles slow you down (mud, chickens, lawn chairs)
- First to finish wins; time bonuses for hitting obstacles into opponents
- Simple physics: velocity with friction, no rotation needed

#### 3. Hurricane Party
- Falling objects rain down (debris)
- Players move left/right to catch "party items" and dodge "deadly debris"
- Objects categorized as good/bad at spawn; score +1 or -1 on catch
- Highest score when timer runs out wins

#### 4. Rocket Man
- Side-scrolling, players control a rocket's vertical thrust
- Avoid cave walls (procedurally placed obstacles)
- Survive longest / travel furthest wins
- One button: hold = thrust up, release = fall

#### 5. Flamingo Fiasco
- Players and AI flamingos occupy a shared space
- Players tag flamingos by moving into them; each tag = 1 point
- Flamingos scatter on tag (simple flee steering behavior)
- Most tags in the time limit wins

#### 6. Python Hunt
- Grid-based (think Snake, but reversed)
- Pythons move around the grid; players lay traps on tiles
- A python hitting a trap = point for that player
- Snakes multiply over time; game ends when timer runs out

---

### Phase 5: Scoring System

- Each mini-game awards points: 1st = 3pts, 2nd = 2pts, 3rd = 1pt, 4th = 0pts
- Session plays through all 6 mini-games (one full rotation = one match)
- Player with most points after all 6 rounds wins the match

---

### Phase 6: Input Handling

Use Godot's `InputMap` with virtual player slots:

```
player_1_up, player_1_down, player_1_left, player_1_right, player_1_action
player_2_*, player_3_*, player_4_*
```

Assign keyboard or gamepad to each slot at lobby join time. Each mini-game reads from its player's slot only — no hardcoded keys.

---

### Phase 7: Multiplayer (stretch)

Start with local multiplayer only (same machine). Once game logic is solid:

- Add Godot's `ENetMultiplayerPeer` for LAN/online
- Session manager becomes the authority; clients send inputs, server resolves state
- ScoreBoard sync via RPC after each game

---

### Build Order

| Week | Goal |
|------|------|
| 1 | Core flow: MainMenu → Lobby → Selector → ScoreBoard |
| 2 | Base `MiniGame` framework + Lawnmower Race (simplest to test) |
| 3 | Rocket Man + Hurricane Party |
| 4 | Alligator Wrangler + Flamingo Fiasco |
| 5 | Python Hunt + scoring system end-to-end |
| 6 | Input remapping, AI placeholder for single-player, bug pass |
| 7+ | Online multiplayer (optional) |
