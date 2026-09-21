# Survival expansion — September 20, 2026

Implemented all eleven requested changes: slower accelerated movement, sprint hip-fire, batched shrubs with shared movement slowdown, six accessible loot houses and entry steps, preserved bridge routes, text-only intro, original adaptive ambient score, chase growls, synthesized tearing/pain effects, and per-hunter lycanthropy.

## Checked

- `test_survival_expansion.gd`, headless and native: walking speed; sprint plus right-mouse blocks sights/zoom and increases spread; vegetation slowdown for both species; six doorway collision openings; both player and wolf navigation actually walk into each building; houses are not sanctuaries; free single-claim loot; infection, all five blur stages, full-moon health/speed and ordinary-wave restoration; retry clears infection.
- Native mode additionally verifies both music layers are playing, alert ramps tension up, and calm ramps it down. Sound effects are original synthetic Foley/vocal synthesis, not actor recordings. Subjective sound balance may still need player feedback.
- `test_player_weapons.gd`: 127 checks passed. Updated the movement-distance assertion for the intentionally slower acceleration; musket loading still locks movement.
- `test_game.gd`: 62 checks passed. `test_survival_loop.gd`: 51 checks passed.
- `test_shots_exploration.gd`: all twelve crossings pass player/wolf travel and actual pursuit checks; anatomy, level-one start, cabin safety and wallet-preserving death pass. Fixed a dockside footprint conflict with the southern bridge. Connected navigation: 124,614 nodes.
- `test_coop.gd`: three localhost processes passed shared wave/rewards and friendly fire. One run logged an ENet send warning/error as a peer disconnected; gameplay assertions completed successfully. Internet latency/loss and long-session stability have not been evaluated.
- `test_coop_loot.gd`: two localhost processes verified remote pickup ownership, shared removal of the pickup, a remote werewolf bite infecting the client, and that client's full-moon recovery to 200 HP with 1.5x speed. Both processes passed without errors.

Tests use isolated saves. Native visual captures used Godot 4.6.2 Compatibility on RTX 3080 at 1280×720. This is not a full new performance benchmark.

## Captures

- [Opened neighboring house](house.png)
- [Fifth incubation round: blur with readable HUD](curse_9.png)
- [Mature full-moon effect and 200 HP](curse_10.png)

Curse screenshots deliberately hold the same daytime camera/weather for comparison. Actual fifth-wave gameplay forces the existing red full-moon night.

Interiors, openings, floor clearance, stairs and undergrowth are game-only additions. The original island and surrounding source GLBs and as-is Blender model were not edited.
