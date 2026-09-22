# Gameplay expansion validation — 2026-09-22

Godot 4.6.2, Windows. Tests use isolated/transient saves.

- `test_gameplay_expansion.gd`: 27 checks; moose health, provocation after a flinch, ambient spawns, danger-only extended radar, four navigable cardinal towers, station travel and return, invalid travel rejection, five-second flame capacity, multiple targets in the cone, range limit, once-per-target damage, throwing balance, ten-damage defensive stabs, three-second escape knockdown, permanent wolf damage boon.
- `test_split_session.gd`: 70 checks; equal custom starting credits, equal reward increments, duplicate-message rejection, authoritative kill rewards, main-cabin spawns, exclusive input ownership, controller fast travel and position validation, moose replication, remote stabbing, escape flinch, existing revival/ritual/weapon controls.
- `test_dark_ritual.gd`: 63 checks, including moose eligibility and modifiers that persist across rounds.
- `test_affliction_flame.gd`: 20 checks, including flame damage, wall occlusion, held/released trigger, and psychedelic/lycanthropy interactions.
- `test_weapon_balance.gd`: 112 checks, including price bounds, stat guide and explosive replenishment.
- Native rendering captures: moose, all four towers, travel menu, impact/anatomy views and permanent boon HUD. Tower selection checks the whole footprint and avoids the surroundings foliage mesh. Original island asset is unchanged.

Combat assertions use elevated isolated fixtures to exclude existing terrain from damage tests; visual captures move the moose back onto the actual map. Controller events are simulated through the real split-screen input route, not a physical-controller endurance playtest. No new frame-rate benchmark is claimed.

Permanent boons mean the current run: cabin rest does not remove them; a new run does. Moose remain non-hostile in Free Play. Wallet purchases remain individual; rewards are shared equally.
