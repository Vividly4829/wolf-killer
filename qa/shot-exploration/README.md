# Shot zones and coastal crossings — 2026-09-19

Implemented in the native Godot project. The screenshot `xray-bridge.png` comes from the native OpenGL renderer at 1280×720, showing the southern crossing and the original vector anatomical review.

Validation:
- `tests/test_shots_exploration.gd`: organ trajectories, short penetration versus double lung, localized legs, actual wolf damage/bleeding, nonblocking review, one-wolf opening, death reset with money retained, all three bridge destinations reachable, walking both directions, wolves following the actual pursuit fields, inaccessible sea and safe cabin exclusion.
- `tests/test_game.gd`: 62 game integration checks passed.
- `tests/test_survival_loop.gd`: 51 survival integration checks passed; its three-wolf fixture now explicitly begins on level 2.
- `tests/test_surroundings.gd`: 82 checks passed, including unchanged hashes for the original island assets. Coastal collision/navigation expectations now reflect the requested exploration feature.

Coastal navigation adds a sparse one-metre graph to the original quarter-metre grid. Bridge deck heights overlay only in-memory gameplay samples. Runtime pursuit searches are spread across approximately 2.5 ms slices, keeping the previous completed field available until replacement. Bridge boards, posts and rails share one instanced rendering batch. The minimap uses simplified coast outlines.

An uncapped native diagnostic measured approximately 256 FPS with the shot panel, southern bridge and one frozen test wolf, with a maximum navigation slice of 3.2 ms on the RTX 3080. This is a controlled rendering check, not a full combat or large-pack FPS benchmark. The first pass exposed expensive unsimplified minimap coast polygons; those were simplified before the final measurement.

Reproduce: launch `Godot_v4.6.2-stable_win64_console.exe --path godot --script res://tests/test_shots_exploration.gd -- --capture` from the workspace root. Without `--capture`, the test also supports `--headless`. Test saves are isolated and removed.

The crossings are fictional gameplay additions. No bridges were added to the surveyed as-is Blender model, and the original island GLB/world JSON are unchanged. Regenerate only the additional exploration JSON with `scripts/build_game_exploration.py` using the saved geographic reference data.
