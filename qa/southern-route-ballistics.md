# Southern routes, movement and shot review — 20 September 2026

The southwest rock stub was replaced by a crossing to real mainland ground, with two bank approach ramps. Added approach ramps to the longer south-island crossing too. Rebuilt game-only exploration navigation with `scripts/build_game_exploration.py`; source island and surroundings GLBs remain unchanged. Native renders inspected: `southwest-mainland-footbridge.png` and `south-island-footbridge.png`.

Standing eye height is 1.78 m (previously 1.65), walking 2.85 m/s (2.45), sprinting 5.4 m/s (4.7). Acceleration, sprint aim penalties, crouching, injury and vegetation modifiers remain active.

Firearms now resolve gravity-aware swept collision segments, with exactly the same sample points used for review. This is immediate segmented ballistic tracing, not a time-delayed bullet entity. Musket speed is a gameplay-tuned 180 m/s, other firearms 300 m/s, gravity 9.8 m/s². Bows and throws retain their existing time-stepped projectiles; lasers remain straight. The graph removes launch-angle slope and explicitly magnifies vertical displacement below the aim line. It ends at the actual collision or range limit; no decorative continuation after impact.

X cycles through a per-hunter ring of 32 shot records, including misses. D-pad down does the same for P2. Expired panels reopen the latest shot first. New shots select the newest record, while late projectile results update their original record. New runs clear history. Pellets remain grouped by shot.

Knives: three ready throws, no reserves, 0.22-second interval, 32 m/s. Spear: one, no reserves, 160 base damage, 30 m/s. Store refills restore only these carry limits (one credit per knife, six per spear); bed recovery replenishes them normally. Free Play R restocks the practice carry limit. Campaign R cannot create extra thrown weapons.

## Verification

- `test_map_connections.gd -- --capture`: 223 checks passed in native Godot. All 25 spans/ramps cross in both directions, including offset lanes; five main footbridges have extra landing checks. All context cabins are reachable and no disconnected walkable patch of eight or more nodes remains.
- `test_shot_paths.gd`: 40 final checks passed, including actual walking/sprinting and camera height on the south bridge, firearm curvature, downhill graph readability, a thin target hit by bullet drop but missed by a straight laser, precise impact termination, pellet paths, projectile arcs, repeated X input/wrapping, bounded history, overlapping projectile results, damage-copy isolation, ammunition limits/refills and Free Play replenishment.
- Native shot-review run passed before the additional movement/collision assertions were added. Visually inspected `shot-path-downward-arc.png`: the displayed path is curved against a horizontal dashed aim line and includes measured drop.
- `test_split_session.gd`: 38 headless checks passed, including both shooters' authoritative paths, controller-only P2 history browsing, keyboard isolation, existing coffee/store checks and round/death recovery. Mouse capture is covered by the earlier native run; the dummy display skips it.

Logs: `south-connections-final.log`, `ballistics-history-final.log`, `ballistics-history-native.log`, `ballistics-history-split.log`. Automated input and navigation plus rendered inspection; not a manual controller playthrough.
