# Map crossings — 20 September 2026

Added three game-only timber crossings: north island to mainland, southern
cove to mainland, and the southern end of the west islet to mainland. Together
they create shorter loops through the inhabited areas. Each crossing has two
bank approach ramps; heights clear the convex shoreline rather than passing
through it. Visible pilings support the new spans.

The bridge footprint now uses a fixed 0.6 m landing overlap. The old percentage
overlap left an off-center lane blocked at a short ramp's last rounded grid cell.
Visual deck lengths match this overlap. Navigation and the HUD map use the
regenerated exploration data. The source island and surroundings GLBs were not
edited.

Validation:

- Native Godot `test_map_connections.gd -- --capture`: 187 checks, zero failures.
  Player and wolf navigation crossed all 21 spans/ramps in both directions at
  the center and at +/-0.6 m offsets. The three new spans also passed their
  two-metre shore approach checks. All six context house interiors are reachable.
- Flood fill found no disconnected walkable land patches of eight or more cells.
- `world_smoke.gd`: zero failures; 124,879 player cells and 124,294 wolf cells
  reachable. Cabin safety, room access, exit movement, shop blocking, open-water
  blocking, and effect cleanup passed. Updated its obsolete open-water fixture:
  (-100,-100) is mainland in the expanded map; (80,40) is in the open sound.
- Inspected native daylight captures of all three new crossings.

Logs: `map-connections-native.log`, `map-connections-world-smoke.log`.
Rebuild exploration data using `scripts/build_game_exploration.py`.
This is automated navigation movement and rendered inspection, not a manual
controller playthrough.
