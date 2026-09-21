# Combat feedback validation

Verified with bundled Godot 4.6.2 on 2026-09-21, using isolated test saves.

- `test_combat_feedback.gd`: replica death collapse with physics disabled, limb injury replication, wildlife health-field compatibility, radar range/colours, 1,000 early pack draws and cumulative pack cap, quick-throw priority/ammo/recovery, injury indicators, new weapon models, dual hand switching, bear recording, launcher retention.
- `test_split_session.gd`: local two-player startup, input ownership, weapon interactions, shot review delivery, friendly fire, recovery/retry, and a host-killed wolf visibly collapsing in the second viewport. No script errors in the final run.
- `test_shot_replay.gd`: four-second timing, actual sample interpolation, pause/history, pellets, misses, late arrow completion, network serialization, split-screen layout and cleanup.
- Native renderer captures inspected: `combat-weapon-33.png`, `replay-impact.png`, and the injury/context display in `combat-weapon-32.png`. Test captures deliberately apply injury states. The trajectory target uses metric vertical positioning with enlarged horizontal anatomy for readability.

Character artwork is original stylized frontier-ranger geometry, not extracted Fallout assets. The Luger is a requested later-era exception; the 1889 launcher is explicitly fictional. Bear recording attribution is in `assets/audio/MAUL_AUDIO_LICENSE.md`.

These are scripted gameplay and native-render checks, not a new measured frame-rate benchmark or a completed internet multiplayer soak test. Restart any running game to load scripts/assets.
