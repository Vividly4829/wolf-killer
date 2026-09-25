# Saved wallets, Continue and paid revival

New profiles start with zero credits. Existing balances are preserved, with no automatic starter-credit top-up. The starting level and credit controls are hidden until WOLFMASTER is entered (case-insensitive). Unlock lasts for the current application session. This is a convenience cheat gate, not an anti-tamper system.

Merely starting or continuing a game no longer copies the host's wallet into other player profiles. An explicitly changed unlocked starting-credit value still applies to every player as before. Local player slots retain separate files; online players retain their local profile.

Progress schema 3 stores the last resumable level and local player count alongside the existing wallet and equipment. Save points include starting a round, advancing a round, returning to the menu, and window close / Save & Quit for every local viewport. Continue restarts that level from the cabin, rather than restoring an exact mid-combat world snapshot. New expedition starts level one and keeps banked credits. Solo death / team defeat clears Continue, so exiting cannot bypass the death reset.

Paid revive costs 1,000 credits from the downed player's own wallet, restores 10 HP at the cabin, and keeps the current round. Purchased weapons already lost on death remain lost. It works solo, while teammates remain alive, and following a team wipe. The host validates co-op death state and life/generation before acceptance; repeat requests cannot charge again. Existing nearby teammate revival remains free. Controller X activates paid revival on death/waiting screens and Continue on the main menu.

Validation: new solo regression covers zero balance, code gate, disk reload, Continue, death invalidation, exact revive charge, duplicate and insufficient-funds refusal. New co-op regression covers independent saved balances, resumed level in both viewports, guest/host revival, team-wipe recovery and disk persistence. Existing teammate-revive and split-session regressions also exercised. Native menu and defeat layouts reviewed at qa/continue-menu.png and qa/paid-revive-menu.png. EXE not rebuilt in this update.
