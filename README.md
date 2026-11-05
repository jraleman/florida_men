# Florida Men

A native `godot-base` party game: a 24-space board, six original procedural
3D minigames and four holiday guests. Play offline with **1-4 local humans**;
rule-aware CPUs fill the remaining seats. Mobile uses one human and three CPUs.

Open the **parent `godot-base` project**, not this folder. The old nested
project, duplicate autoloads and standalone menus have been removed. The shared
framework supplies setup, settings, instructions, pause, results, achievements,
store, gallery, saves and share images.

## Run

From `godot-base` with Godot 4.7 and the Compatibility renderer:

```powershell
godot --path . -- --game=florida_men
godot --path . -- --game=all
```

In the collection, choose **Florida Men**, the number of humans and each
human's holiday guest. Unclaimed seats are visibly labeled CPUs. Settings >
Game chooses **5, 6, 10, 20 or 30 minigames** (default 10) and CPU reaction speed.
The six-game setting visits every headline once; longer parties repeat the
seeded rotation. Briefings and between-game standings wait for a player.

## Rules

Every guest starts with **10 board coins**. Each board round gives all four
seats one die roll, then one minigame. Tile marks identify their effects:
landing on GO +3, ordinary 0, Sunshine +2, Puddle -2, Bonus +2 to +4, Detour -1
to -3. Coins cannot fall below zero. Passing GO does not pay.

Minigame placements pay **5 / 3 / 1 / 0 coins** and **3 / 2 / 1 / 0 placement
points**. Equal results share competition placement and its reward; a tie does
not favor an earlier seat. After the selected number of minigames, **most
coins wins**, with minigame wins breaking equal coin totals. Equal coins and
wins produce shared champions. Placement points are descriptive, not another
party tie-breaker.

| Minigame | Play |
| --- | --- |
| Alligator Wrangler | Move on the 8x8 grid onto the toy gator. First to three wrangles wins; the gator gets quicker. |
| Lawnmower Race | Change between three lanes. Mud, chickens and chairs slow the mower; the first finisher ends the race. |
| Hurricane Party | Move left/right, catching ribboned +1 gifts and avoiding wooden -1 debris. One guest catches each item. |
| Rocket Man | Hold action to thrust up, release to fall. Survive cave gaps and boundaries; surviving pilots rank ahead of eliminated pilots. |
| Flamingo Fiasco | Move into toy birds to tag them. They flee, then wander again; each bird has a short per-player tag cooldown. |
| Python Hunt | Move on the 12x12 grid and tap action to leave an owned catch crate. A toy python entering it earns a point. |

Minigames last at most 30 model seconds. The toy wildlife, weather and rockets
are fictional game props, not real-world handling or safety advice.

All four guests appear in the shared results and statistics panels. Compact
windows scroll the report so its controls remain reachable.

## Controls

| Seat | Movement | Roll / thrust / crate |
| --- | --- | --- |
| P1 | W A S D | Space |
| P2 | Arrow keys | Enter |
| P3 | I J K L | U |
| P4 | Number-pad 8 / 4 / 2 / 6 | Number-pad 0 |

All 20 keys are rebindable through the shared Controls tab. Each assigned
controller uses its left stick or D-pad and A. Independent on-screen direction
and action contacts control P1 on touch devices. Escape or controller Back
opens the shared pause menu. Inputs clear on pause, focus loss, phase changes,
rebinding and controller reassignment. Keyboard rollover and real controller/
multitouch behavior still need physical-device testing.

## Souvenirs and sharing

**Sunshine Tokens** are persistent shop currency, separate from board coins.
Only a completed party pays: `min(75, 5 + floor(best_human_coins / 2))`.
Leaving early, rolling dice and advancing individual minigames never pay.
Hats are cosmetic; ownership is shared within the game, with four independent
equipment slots, including CPU guests. Purchasing also wears the item in the
first available slot, as in other framework stores.

Four achievements recognize completing a party, three human minigame wins,
40 human board coins and a human overall champion. The free eight-exhibit
gallery, setup previews, shop and frozen share portraits reuse actual play
geometry. Finished shares retain all four scores, standings and outfits even
after a later equipment change. The QR opens the studio homepage; it does not
claim a public run record.

The shared Saves screen handles achievements, tokens and purchased/equipped
items. An in-progress party is session-only. No online multiplayer or account
service is implemented.

## Implementation and tests

| Path | Responsibility |
| --- | --- |
| `game.gd`, `florida_men_options.gd`, `intro.tscn` | Manifest, standalone opening, rebindable controls, options, store and gallery declarations |
| `model\party_match.gd` | Node-free dice, board effects, rotation, placements, standings and completed-party payout |
| `model\mini_game_state.gd` | Six node-free 120 Hz simulations and rule-aware CPU steering |
| `gameplay.gd` | `GameShell` orchestration and genuine keyboard/controller/touch input |
| `world\` | Original reusable meshes and isolated aspect-aware Compatibility worlds |
| `presentation\`, `audio\` | Setup/store/gallery/share adapters and original synthesized music/cues |
| `tools\tutorial_driver.gd` | Real rebound-key walkthrough of one complete six-game party |

From `godot-base`:

```powershell
godot --headless --path . --script res://games/florida_men/tests/party_model_test.gd -- --game=all
godot --headless --path . --script res://games/florida_men/tests/party_scene_test.gd -- --game=all
godot --path . --script res://games/florida_men/tests/party_view_test.gd -- --game=all
```

The scene suite drives all four human seats with actual keys, rebinding and
pause, then completes all six minigames through the real shell. It restores
the exact original store/achievement files. The view suite **requires a real
graphics window** and checks desktop, portrait, short-landscape and ultrawide
framing, four-seat HUDs and real rendered geometry. Run the host's 15 framework
suites as well when changing framework integration.

Re-record only this game's silent instructions clip and poster after changing
visuals or captions:

```powershell
pwsh tools\record_tutorials.ps1 -Godot 'C:\Godot\Godot.exe' -Games florida_men -Variants solo
```

## Standalone builds

The parent project has Windows, Web, Android and iOS presets named
`<platform> - Florida Men (standalone)`. They select the `florida_men` feature,
exclude other games and development tools, disable audio input and use the
stable `DeskCanSaw Games\Florida Men` save directory. Android/iOS use adaptive
orientation. Keep the renderer `gl_compatibility`.

Export templates are required. Android release signing and iOS team/
provisioning must be configured by the release owner. Physical controllers,
phones/tablets, browser performance, mobile signing and human gameplay/balance
review are release checks, not established by desktop automated tests.
