# Shooting range / Free Play verification

September 20, 2026, Godot 4.6.2. `test_free_play.gd` passes 17 checks in headless and native modes:

- All 24 weapons available in an in-memory inventory.
- Range on connected, walkable land; actual physics rays reach all three targets and register hit scores/damage.
- Wildlife and three wolves present; nearby wolves cannot attack after gunfire.
- No campaign objectives start, and ammunition reserves replenish.
- Attempted practice saves leave the isolated campaign save byte-for-byte unchanged.
- Menu return restores the exact campaign progress object, wallet and ownership; campaign play starts normally afterward.

Native screenshots were inspected at 1280×720 on RTX 3080 using Compatibility rendering. A target-identification issue found during the first native run was fixed; the final native run completed without script errors.

- [Range](range.png)
- [Main menu](menu.png)

Run with `--headless --path godot --script res://tests/test_free_play.gd`; omit `--headless` and append `-- --capture` for screenshots. Tests use isolated saves. Original island/source model assets remain untouched.
