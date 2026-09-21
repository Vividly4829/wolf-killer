# Shot distance and trajectory review

Every firearm ray/pellet and travelling projectile now records its actual combat
path, including terrain impacts and range-limit misses. The bottom-right review
shows distance travelled, horizontal range, drop relative to the initial aim,
and a side-view plot with a dashed aim line and an endpoint marker. Misses use
the space otherwise occupied by the skeleton for a larger graph; hits retain
their anatomy and damage calculation. X reopens the last report.

Firearms and the laser retain their existing straight hitscan behavior and
explicitly show a straight path/zero drop. Bows, crossbows and thrown weapons
show sampled curved flight, including wind effects. The plot scales its axes
independently and says so. No artificial bullet arc or new firearm ballistics
has been introduced.

Projectile distance is measured to the exact collision point, not the end of
the physics step. The final step is clipped at the weapon's range limit. Flight
samples are capped at 64, pellet paths at 18, and live updates at five per second.
The shooter receives host-calculated results in co-op; serial checks reject
late results belonging to a previous shot.

Validation: `test_shot_paths.gd` passed 17 checks in headless and native Godot.
Includes firearm and crossbow range-limit misses, individual shotgun pellets,
wall impacts, thrown weapon drop, exact projectile endpoints, stale reports,
and anatomy plus trajectory in one panel. Inspected native captures of a miss,
curved miss, and a human X-ray with its trajectory.

Split-screen regression additionally checks independent firearm/pellet reports
and a completed controller-fired projectile arc delivered by the host. Logs:
`shot-paths-native.log`, `shot-paths-split.log`.
