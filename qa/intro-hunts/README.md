# Introductory hunts

September 20, 2026. Level 1: one deer from four spawned targets. Level 2: two deer from four targets. Level 3: one aquatic goose from three swimming near the southern crossing. No wolves spawn before level 4; wolf counts then start at one and increase by two. The existing level-5 full moon remains in place.

`test_intro_hunts.gd` passes 25 checks covering all four objective transitions, wrong-species rejection, no early wolves, multiple targets, quiet versus loud approach, gunshot fear, actual wounded-deer movement, bleeding/blood spots, water-only goose movement and death reset. The native run also captured [swimming geese](geese.png). The HUD was subsequently shortened to keep its objective label inside the panel.

`test_coop.gd` passed with three separate localhost processes: clients see the opening wildlife without wolves, shared rewards and friendly fire still work. Objective kills, fear state and wound trails are replicated from the host. Internet conditions were not tested.

Existing wolf-specific regression fixtures were moved after the introductory hunts. The survival injury fixture deliberately retains its three fixed ordinary wolf profiles so its ammunition and mauling assertions remain independent of the new campaign sequence; the new introductory-hunt test checks real progression.

All tests use isolated saves. Player wallet data and original island assets were not changed.
