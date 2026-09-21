# Playtest polish — September 20, 2026

- Opening wave: ten deer and ten other wildlife actors, including nearby targets and additional animals distributed across connected terrain. Objective remains one deer; no opening wolves.
- Adult-proportioned leather gloves replace the small bare hands.
- Firearm aiming uses authored sight heights, including transformed break-action assemblies. Removed the musket's non-reloading pose override, suppressed independent weapon sway while aiming, added sights to pepperbox/derringer and cocked loaded hammers clear of the sight line. Sharps tang sight folds down while barrel sights are used.
- Bridge walking follows the rendered deck plane. Connected ground samples interpolate height; house approach steps use continuous walking slopes and solid visual risers. Connectivity and inaccessible water rules remain intact.

Validation on Godot 4.6.2:

- `test_playtest_polish.gd`: 32 checks, including all 18 original firearm/crossbow aiming anchors, all 12 bridge planes, opening population and distant wildlife. Native OpenGL captures of musket, Colt Navy and Sharps reviewed at 1280 x 720.
- `test_shots_exploration.gd`: all crossings traversable both directions, player and wolf connectivity and actual pursuit fields passed.
- `test_intro_hunts.gd`: opening progression, animal behavior and death reset passed.
- `test_player_weapons.gd`: 127 checks passed.
- `test_weapon_visuals.gd`: 423 checks passed.
- `test_weapon_model_cache.gd`: 124 checks passed.
- `test_player_hunting.gd`: 32 checks passed after updating its old test double and obsolete walking-speed assumption.
- `test_survival_expansion.gd`: house entrances, navigation, sprint, brush and survival regressions checked.

Saves are isolated from player progress. Native capture teardown reports an ObjectDB leak warning; no capture or gameplay assertions failed. This is traversal/visual validation, not a fresh frame-rate benchmark. No original island GLB or as-is model was edited.
