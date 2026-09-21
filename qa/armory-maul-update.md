# Armory, wallets and wolf struggles — 21 September 2026

Implemented latest nine requested changes in native Godot source. New stable IDs 27–30 preserve existing weapon saves. Store stowing is per design (all copies), persisted, preserves magazine state until normal wave replenishment, and is lost on death as intended. At least one design must remain carried.

Validation:
- `test_armory_maul.gd`: 41 checks passed headless and native OpenGL on RTX 3080. Exercises purchases, model construction/reloads, right-left firing and reset, stow/cycle/save/re-equip with partially spent ammo, laser thickness/color, recorded audio resources, typed-but-uncommitted menu money for both split hunters, repeated ready-handshake protection, round wallet persistence, safe-player and dead-attacker maul release.
- `test_wolf_building_exits.gd`: 12/12 exits passed, sizes 0.85 and 1.30, all six neighboring buildings, real map navigation and wolf movement footprint.
- `test_start_options.gd`: 12 checks passed after fixing SpinBox commit handling. Death does not regrant custom money.
- `test_split_session.gd`: all applicable checks passed, including controller ownership, buying, coffee, friendly fire, projectile/X-ray isolation, recovery and team wipe. Headless mouse capture check skipped by existing fixture.
- `test_duplicate_guns.gd`: 49 checks passed after expanding catalog.
- Native images inspected: `armory-27.png` through `armory-30.png`, `naval-first-person.png`, `red-laser-first-person.png`.

Limits: rendered split-session teardown reports four 256px OpenGL texture cleanup warnings (also present in the earlier `start-options.log`); no script errors or assertion failures in the completed new suite. This is not a long-duration performance benchmark. The legacy `test_pack_behavior.gd` fixture lacks the current game's `nodes_in_group` method and was stopped; actual-map exit and multiplayer struggle checks were used instead. Audio resources and scheduling were verified, not a subjective listening test.

Model and audio sources: see README and `assets/audio/MAUL_AUDIO_LICENSE.md`. Mauser C78 chosen to preserve the existing pre-1890 constraint; no clarification response was received. Naval pair is an original fictional design. Actual player saves and original island geometry were not edited. Test saves are isolated and cleaned up.
