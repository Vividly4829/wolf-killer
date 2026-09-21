# Deer shoreline regression — 2026-09-20

The original movement test reproduced exact overlapping deer at the shore (minimum pair distance 0 m). Escape selection snapped six-metre targets back to the beach, provided no separation, and repeatedly retried blocked goals.

Changes:

- Prefer open habitat at spawn and when selecting destinations; sample multiple directions and distances, with individual heading variation.
- Prefer connected local exits over waiting for an unnecessary detour search. Keep incremental A* for enclosed obstacles.
- Penalize crowded destinations and separate nearby ground animals while respecting terrain links.
- Remember failed goals; detect lack of progress and retry a different route. Do not cancel an unfinished incremental search simply because its animal has not yet moved.
- Follow corners without velocity sliding into blocked shoreline cells; stagger goal choices to one per physics frame.

Validation using Godot 4.6.2 headless:

- `test_deer_shore.gd`: four real coastal fixtures, three initially overlapping deer at each, 24 simulated seconds. All ten normal deer spawns passed habitat checks; all twelve stressed deer stayed on navigable terrain, recovered without prolonged stalls, and separated. Maximum measured low-progress interval: 1 second. Closest final pair: 3.62 m.
- Second seed, 60 simulated seconds: all twelve stayed navigable and separated; maximum low-progress interval 2 seconds, closest final pair 3.85 m. This earlier test invocation exercised movement but did not include the subsequently corrected initial spawn assertions.
- `test_intro_hunts.gd`: passed detection, wounded flight, blood trail, deer/goose objectives, waterbird movement and death-reset checks.

The final 24-second run measured only the twelve animals' scripted movement update: median 0.965 ms, p95 3.868 ms, maximum 5.737 ms. These are headless AI timings, not rendered frame-rate measurements. Results do not guarantee every possible terrain/threat combination is covered.

Logs: `deer-shore-before.log`, `deer-shore-after.log`, `deer-shore-soak.log`, `deer-intro-regression.log`. Tests used isolated saves. Existing island geometry and player progress were unchanged.
