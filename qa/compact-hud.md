# Compact HUD, misses and round earnings

- Gameplay widgets shrink around their screen-edge anchors; menus retain their normal layout. X restores the original HUD size for eight seconds and continues cycling shot history. Each split-screen player has an independent detail view.
- Automatic miss reviews use 38% opacity, including the replay, while preserving range and trajectory. Explicit review restores full opacity.
- Sprint speed is 6.075 m/s; stamina capacity is 337.5. Both are 75% of the previous values. Sprint firing remains disabled.
- Gross round rewards are tracked by the host and included in hunter snapshots for every connected player, with stable P1/P2/P3 labels. Spending does not subtract earnings. New runs and next-round cabin wakes reset the ledger.

Validation: `test_compact_hud.gd`, `test_shot_replay.gd`, `test_hunting_combat_polish.gd` and `test_split_session.gd` passed. Native graphical runs of the compact HUD and split session passed; compact/expanded miss reviews and the two-player HUD were visually inspected. Tests use isolated or transient progress profiles.

The rebuilt Windows executable also completed the headless gameplay smoke run with exit code 0 and `VISUAL_QA_COMPLETE`.
