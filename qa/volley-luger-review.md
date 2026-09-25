# Volley gun and Luger drum review

Added stable weapon ID 36 (`nock_volley`) without changing existing save IDs. Available in the store, free play and the paged armory: 750 credits, seven simultaneous 85-damage balls, one charge, eight spare volleys, eight-second actual reload, 35 m effective range / 85 m maximum trace range. Damage falls off with distance; each ball uses the existing hit-zone, penetration and X-ray systems. Gameplay values are balance choices, not historical measurements.

Original procedural model follows the supplied seven-barrel reference: one central barrel surrounded by six, individually hollow muzzles, wood shoulder stock and checkered wrist, side flintlock, trigger guard, ramrod and iron sights. Seven synchronized muzzle flashes and flame tongues; reload animation works across the seven bores. Static geometry remains batched into 14 meshes.

Corrected Luger TM08 drum from a sideways cylinder to a tilted fore/aft-facing drum beneath the extended grip. Feed tower, reinforcing rings and winding handle move with the magazine during reload. Updated both weapon icons.

References consulted: [Charleston Museum volley gun](https://www.charlestonmuseum.org/research/collection/volley-gun/89A34D29-47C0-46B6-B43B-286472425376), [Australian War Memorial TM08 magazine](https://www.awm.gov.au/collection/C396412), and [Rock Island Auction mounted Luger drum photograph](https://www.rockislandauction.com/detail/4094/1414/dwm-1914-artillery-luger-pistol-rig-with-snail-drum-magazine). References informed shape/orientation; no external model assets used.

Validation: Godot 4.6.2 import clean; 709 weapon visual checks; 189 model-cache checks; weapon balance/menu paging checks passed. New live firing regression confirms seven recorded trajectories per trigger, charge consumption, seven flashes and reload start. Native RTX 3080 captures inspected for hip, aim and reload poses, plus both armory icons. Logs/captures are local in qa/volley-*. Windows executable was not rebuilt for this source change.
