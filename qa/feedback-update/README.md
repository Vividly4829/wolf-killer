# Playtest update — 20 September 2026

Implemented random wake seasons/hours, scattered world-wide wolf spawns, bottom-right 3D bone shot review with damage calculation, six cheap field weapons (24 total), physical aiming without a crosshair, revised hands, twelve crossings, three-player ENet co-op with friendly fire, sharper wolf fur, a large quadrupedal werewolf every fifth wave, automatic cabin doors including a real backdoor, stove fire/tea, and optional wildlife/predation.

## Verification

Using bundled Godot 4.6.2:

- `test_feedback_update.gd`: seasons/time, fifth-wave override, shelter firing restriction, physical backdoor and door closing, six new weapons/models, boss, wildlife rewards and predation passed. Native `-- --capture` also verified an actual firearm damage report.
- `test_armory.gd`: 244 checks passed, including all purchases, ammunition, reloads, projectile travel/drop/collision and equipment loss.
- `test_player_weapons.gd`: 127 headless checks passed; captured-mouse checks require its native mode.
- `test_weapon_model_cache.gd`: 124 checks passed for 24 independently instantiated models.
- `test_progress.gd`: 47 checks passed; intentionally malformed-save recovery logs a parser error as part of the fixture.
- `test_survival_loop.gd`: 51 injury, rest and survival checks passed.
- `preview_armory_store.gd`: all 24 previews, transactions, filters, scrolling and selection passed.
- `test_shots_exploration.gd`: anatomical paths, level-one wolf, all twelve crossings both directions, wolf pursuit, safe cabin, water boundaries and wallet-preserving death passed. Connected navigation contains 124,319 nodes. Runtime navigation work is sliced across frames; synchronous test construction time is not a gameplay frame measurement.
- `test_coop.gd`: three independent localhost ENet processes connected, replicated a wave, shared rewards and delivered both a real client-fired friendly shot and host-applied damage. Final run completed without errors. Public internet, adverse latency and extended sessions remain untested.

Run a test from the workspace root with:

```powershell
& godot/tools/Godot_v4.6.2-stable_win64_console.exe --headless --path godot --script res://tests/test_feedback_update.gd
```

For the co-op test, start three processes with `--script res://tests/test_coop.gd -- --role=host`, `--role=client1`, and `--role=client2`, respectively. Tests use isolated save paths and preserve the player's wallet.

## Native visual inspection

Captured at 1280×720 using the NVIDIA RTX 3080 compatibility renderer:

- [Cabin stove and steaming tea](cabin.png)
- [Red full moon and larger werewolf](werewolf.png)
- [Bone X-ray and damage calculation](bone-xray.png)

These are staged visual checks, not a new comprehensive frame-rate benchmark. Bones, birds and weapon/hand models remain original stylized geometry. Co-op uses host/join by address on UDP 27896, without public matchmaking or competitive anti-cheat guarantees.

SHA-256 checks confirmed the protected source files remain unchanged:

- As-is Blender: `21dc961b62eeb887ac93348e91d406df141d1d367f0dd30c3d55476db4fc0576`
- Original island GLB: `b1608663daa9d03a014a6335f6670ea44178a132383b88662e82ba27832ab471`
- Original world JSON: `4773174eb25a3625ebc7e222bd86ec6e26a8abaeb8d75cecdad20f5fd50359f9`
