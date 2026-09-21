# Hunting upgrade validation — September 20, 2026

Godot 4.6.2, native OpenGL / RTX 3080 and headless ENet processes.

- `test_hunting_upgrade.gd`: permanent level-five target markers, dozens of physically traversed animal routes including detours, low-damage fatal brain/heart shots for every wildlife species and wolves, knockdown/recovery, 300 stamina and jump, one-use explosive purchases, real blast damage to an animal and thrower, 12-second crank recharge and five actual laser shots followed by an empty-trigger recharge. Final native run passed all checks.
- `test_split_session.gd` plus `test_split_remote.gd`: two local render viewports, isolated physics/group queries, separate buildings and input assignments, injected controller movement/jump, and a third external game process joining. Native split-screen capture inspected. These tests passed.
- `test_coop_respawn.gd`: three-process independent buildings, personal deaths, one survivor completing the objective, wallet/weapon rules, next-round revival and total team wipe. Includes friendly-fire human X-ray and a tiny-damage fatal heart shot.
- `test_intro_hunts.gd`, `test_free_play.gd`: passed progression, frightened/bleeding deer, waterfowl, sandbox inventory and save isolation regressions. The nonfatal-deer fixture was moved away from the heart for the new fatal-vital rule.
- `test_player_weapons.gd`: 142 controller checks passed.
- `test_player_hunting.gd`: 32 checks passed after updating stamina expectations to 300.
- `test_weapon_model_cache.gd`: 139 checks passed after expanding the catalog to 27.

Native captures cover deer, duck, goose and mink X-rays, the new armory and split-screen. Skeleton/organ volumes are stylized gameplay anatomy. The continuous adult hand is an original Blender-authored mesh, with a reproducible generator in `tools/build_adult_hand.py`.

Network testing was on localhost with multiple real ENet peers, not over the public Internet. Controller events were injected; a physical controller and connection latency still require a hardware playtest. No new FPS benchmark was performed. One three-process shutdown logged the existing ENet channel-0 send warning after passing assertions.

Tests use separate save files and remove them afterward. Source island, original world data and as-is Blender model hashes remain unchanged.
