# Expedition overhaul — 20 September 2026

Implemented in the native Godot project; restart the launcher to load it.
Original island/model assets and actual player saves were not modified.

## Gameplay changes

- No pack, supply-cache or cabin-search objectives in any of the 30 waves.
  Former search-only waves now have hunting or raider objectives.
- Dangerous encounter roll on every wave, including opening hunts and moons:
  25% at wave 1, increasing to 85% at wave 30. Background wolf rolls are separate.
  Arrivals investigate the hunter's vicinity instead of remaining at remote sites.
- Independent pack sizes, with increasingly frequent large groups (5–12 later).
- Upright articulated werewolves, short warnings and 11.5 m/s nominal charge speed.
  Terrain/injury modifiers still apply. Original clothed hunter/raider models have
  animated hips, knees, shoulders, elbows, crouching, aiming and attack poses.
- Continuous bush slowdown, obstacle tangent sliding and smoothed ground camera.
- Explosive travel limits no longer delete an armed grenade/dynamite before its
  fuse expires. Detonation produces area damage, fire/smoke, boom and nearby shake.
- Bow grip moved off the aiming point; physical brass sight bead zeroed at 20 m,
  reduced random spread, clearer aiming FOV, unobstructed range instructions.
- All animal/human reviews have side and front views from the same shot data.
  Weapon penetration differs (22 cm knife, 28 cm pellet, 42 cm sidearm, 40–60 cm
  bows, 65 cm crossbow, 70 cm ordinary longarm, 85 cm spear, 115 cm heavy rifles).
  Distance reduces the budget. First body exit ends internal travel; separate
  targets cannot combine their organs in one skeleton. The review shows tissue
  travel. These are simplified game volumes, not anatomical/ballistic simulation.
- Wolf/deer brain volumes are approximately 11 cm wide; their heart volumes are
  roughly 15–20 cm wide before animal size scaling. A projectile must actually
  intersect the volume and reach it. Brain/heart penetration remains fatal.
  Several pellets can legitimately strike different organs in one shotgun shot.
- Gunshot injuries produce bleeding, impact blood, screen blood and camera shake.
  Pain vocals use HaelDB CC0 recordings; see the audio license file.

## Verification

Tests ran with the bundled Godot 4.6.2 on this PC, using disposable test saves.

| Test | Result |
|---|---|
| `test_campaign.gd` | 363 checks, zero failures; all 30 waves completed through actual objective callbacks. |
| `test_expedition_overhaul.gd` | Passed: every wave has goals/no search; increasing danger/pack rolls; all threat dispatch types; character articulation; penetration and target isolation; explosive fuse plus animal damage; bow 20 m zero; gunshot feedback; front X-ray for every supported anatomy type. |
| `test_map_connections.gd` | 223 passes; two-way/off-centre bridge crossings, shore approaches, cabin reachability and disconnected-land audit. |
| `test_deer_shore.gd` | 24 passes; habitat, shoreline escape and crowd separation. |
| `test_woodland_walk.gd` | 51 passes; 48 actual player-controller walks through 24 brush-covered map corridors. |
| `test_werewolf_pursuit.gd` | Actual navigation pursuit: 9.35 m/s peak, charge and maul reached in 2.6 seconds from the test lane. |
| `test_split_session.gd` | 38 passes; immediate two-player start, input ownership, interaction, X-ray controls, friendly fire, recovery and team-wipe restart. |

Woodland walk: 7,432 simulated controller frames, no stalls on clear corridors,
maximum horizontal step 4.75 cm, maximum camera height step 3.08 cm. Measured
controller update median 76 µs / p95 85 µs. This is controller cost, **not full
render frame rate**. Shoreline animal test median 1.55 ms / p95 7.58 ms.

Native rendered captures inspected: `overhaul-characters.png`, `overhaul-bow.png`,
and side/front X-rays for wolves, deer, birds, mink, bear and humans. Captures exposed
an obstructed bow sight and reversed aiming arms; both were corrected and rendered
again. Model detail is batched within joints to reduce draw calls.

This is automated playtesting and rendered visual inspection. It is not a human
30-wave difficulty playthrough, an exhaustive walk over every map point, a fresh
4K FPS benchmark, or a remote online latency test. The campaign's new difficulty
curve still needs player feedback.
