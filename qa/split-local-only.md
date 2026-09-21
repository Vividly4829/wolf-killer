# Local-only split screen — 2026-09-20

The main menu now exposes one LOCAL SPLIT SCREEN / 2 PLAYERS action. It creates two local hunters and starts both games directly after loading. P1 is always keyboard/mouse, P2 is always the first connected controller. Entering from a controller-operated menu does not change these assignments.

Split gameplay state travels through direct in-process calls. Both SceneMultiplayer objects keep OfflineMultiplayerPeer; no ENet listener, IP, UDP port, handshake, connection screen or third slot is involved. Online host/join is blocked for split games. Single-local-player online modes remain separate. The obsolete online-plus-split test and runner were removed.

Validation:
- Native Godot 4.6.2 / OpenGL / RTX 3080: 28 passing checks, exit 0. Includes immediate active startup, separate cabins, WASD/mouse isolation, controller movement/jump, pickup/store/weapon controls, gunshot sharing, friendly fire, last-survivor round completion/revival, team wipe and immediate controller retry.
- `qa/split-local-start.png` was captured from the actual native startup and visually inspected: both panes show live first-person hunters with gameplay HUDs, not joining overlays.
- Headless checks cover the same logic; mouse capture is explicitly skipped on the dummy display and covered by the native run.
- Separate three-process online campaign regression: all processes exited 0 and progression/replication checks passed. One ENet channel warning occurred during teardown; no split-screen socket exists in the new mode.

Tests injected keyboard/mouse/controller events; they are not a claim of a human controller playthrough. All save files and online test ports were isolated from user progress. Existing historical QA describing mixed online/split is superseded by this change.

Sources: `tests/test_split_session.gd`. Logs: `split-local-native.log`, `split-local-only.log`, `campaign-net-{host,a,b}.log`.
