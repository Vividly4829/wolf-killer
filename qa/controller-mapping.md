# Xbox interaction controls — 2026-09-20

Fixed standalone controller activation, event-based button handling (including short taps), device-specific pickup prompts in both HUDs, and store selection scrolling/filter navigation. Existing Xbox bindings now work outside split screen too. Store button events are consumed before GUI focus can trigger a different action.

Validation with native Godot 4.6.2, headless:

- `tests/test_controller_actions.gd`: 18 passing checks. Activation, Y store/pickup, LB/RB switching, single action on hold, D-pad browsing, A purchase/equip with unrelated GUI focus, X ammo, first aid, scrolling, category filtering, B/Y exit, keyboard handoff and disconnect fallback.
- `tests/test_split_session.gd`: 19 passing checks. Includes real ENet pickup authority, separate inventory/store purchases, controller/keyboard isolation, and connection recovery.
- Logs: `controller-actions.log`, `controller-split.log`. Both exited 0 without script errors.

Input events were injected; this does not claim physical Xbox hardware testing. Saves and network ports were isolated from the user's active game. Restart the game to load changed scripts.
