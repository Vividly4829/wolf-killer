# Five-second replay and spare guns

Implemented 20 September 2026 in the native Godot project.

- Adjacent 3D replay follows recorded shot samples and timestamps for 4.5 seconds,
  then holds the impact for 0.5 seconds. It supports misses, vertical shots,
  arrows, multiple pellets, historical reviews and serialized co-op data.
- Struck anatomy is reconstructed at the recorded pose. This is an isolated
  trajectory view, not a recording of animated scenery. New shots replace the
  current replay; X / D-pad down starts an older replay from the beginning.
- Live combat speed is unchanged. Hidden replay viewports stop updating.
- Firearm reload durations divide by three, including LeMat secondary and the
  aether crank musket. Crossbows, bows and thrown weapons are unchanged.
- Buy Another / controller R3 creates a separate owned gun slot. Loaded rounds
  and LeMat secondary barrels are independent. Copies share the model's reserve
  pool, with bundled reserves supplied per purchase and restored per copy at rest.
- Inventory duplication survives saving/loading. Death still removes copies
  and preserves money. HUD labels identify the current copy.
- Werewolf body-hit reviews no longer inherit the human friendly-fire label.

Verification with bundled Godot 4.6.2 and disposable saves:

| Test | Result |
|---|---|
| `test_shot_replay.gd` | 18 checks passed; actual firearm hit/miss traces, timing, pause, history, pellet playback, arrow completion, networking serialization and split panel bounds. |
| `test_duplicate_guns.gd` | 45 checks passed; all reload values, live reload timing, independent copies, secondary chambers, saves, costs, store UI, rest, death and werewolf label. |
| `test_split_session.gd` | 38 checks passed; local input ownership, friendly fire, round recovery and restart regression. |

Native captures inspected: `replay-midflight.png`, `replay-impact.png`,
`replay-miss.png`, `duplicate-guns-store.png`. No script errors in final runs.
Original island assets and actual player saves were not modified during testing.
