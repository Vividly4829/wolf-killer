# Thirty-wave expedition

Restart the native game using `Play Wolf Island.cmd`, then start an expedition.
Existing wallets remain intact. This campaign replaces the old endless wolf-count progression.

## Playing a mission

The HUD lists every requirement. Orange map markers identify required live animals,
while green marks the home bed. All pack-finding, cache and cabin-search objectives are removed.
Hunting objectives count immediately when a hunter kills the required animal.
There is no carrying, delivery, stowing or return trip.

Finishing the last objective automatically starts bed recovery (or victory on wave 30).
Recovery restores health, ordinary injuries, ammo, stamina and two bandages. Shelter
and store visits during a job do not heal injuries; bandages still stop bleeding.
Ammo purchases remain available.

Death loses that hunter's paid weapons and preserves money. A surviving co-op hunter
can finish the remaining objectives, reviving everyone in their assigned buildings.
A team wipe restarts at wave 1. Objectives are shared by two hunters in local split screen, or up to three in separate online play. Split screen cannot join or host online players.
Additional hunters increase later food quotas, ordinary wolves and raider counts;
they do not increase enemy hit points. Required vital hits are still fatal.

## Missions (solo counts)

Every wave can have optional danger. Wolf populations below are minimums, not limits.

| Wave | Title | Job and starting threats |
|---|---|---|
| 1 | First Supper | Hunt 1 deer; optional danger is possible. |
| 2 | Enough for Tomorrow | Hunt 2 deer; optional danger is possible. |
| 3 | Across the Water | Hunt 1 water goose; optional danger is possible. |
| 4 | Something at the Treeline | Kill any 2 wolves. At least 6 start across three independent groups; all are marked on the map. |
| 5 | First Blood Moon | Kill 1 werewolf. 2 optional wolves. |
| 6 | Restock | Hunt 2 deer and 1 goose. |
| 7 | A Quiet Shore | Hunt 1 goose. |
| 8 | The Missing Hunter | Kill 3 wolves. |
| 9 | A Bigger Animal | Kill 1 bear. |
| 10 | Across the Narrows | Kill 1 werewolf. 4 optional wolves. |
| 11 | Three Clean Kills | Hunt 3 deer; explosives ruin meat. |
| 12 | Unwelcome Guests | Kill 3 raiders. |
| 13 | Tea Before Dark | Hunt 2 geese. |
| 14 | Two Packs | Kill 6 wolves in separate groups. |
| 15 | Red Water | Kill 1 werewolf. 5 optional wolves. |
| 16 | Follow the Blood | Track and finish a wounded bear. |
| 17 | The Empty Pantry | Hunt 2 deer and 2 waterbirds. |
| 18 | Crossfire | Kill 4 raiders. |
| 19 | The Forest Feast | Hunt 2 deer and 2 geese. |
| 20 | Two Howls | Kill 2 werewolves. 6 optional wolves. |
| 21 | Lean Hunting | Hunt 3 alert deer; 4 wolves occupy hunting ground. |
| 22 | The Roadblock | Kill 5 raiders. |
| 23 | Pack Country | Kill 8 wolves across three groups. |
| 24 | Nothing Complicated | Hunt a goose from a remote shoreline. |
| 25 | The Red Hunt | Kill 2 werewolves. 8 optional wolves. |
| 26 | Winter Provisions | Hunt 2 deer and 1 goose. |
| 27 | Claimed Ground | Kill a bear. 4 raiders occupy the area. |
| 28 | The Scattered Pack | Kill 10 wolves in separate groups. |
| 29 | Last Provisions | Hunt 2 deer and 2 geese. |
| 30 | Until Morning | Kill 3 werewolves. 6 optional wolves. Victory ends the campaign. |

## Variation and escalation

Every wave rolls an optional dangerous encounter: **25% at wave 1, 44% at wave 10,
64% at wave 20, 85% at wave 30**, increasing linearly. This includes opening hunts
and blood moons. Encounters include wolves, raider patrols, bears and, from wave 6,
stray werewolves. The last encounter is deweighted to reduce repetition.

Warning cues occur after 12–36 seconds, or sooner after repeated gunfire. Actual
arrivals follow six seconds later. Fast completion can avoid an arrival. Enemies
investigate the hunter's area, entering on reachable ground away from hunters,
preferably off-camera or occluded and roughly 48 metres away. Optional threats
never add objectives; optional wolves can satisfy wolf quotas.

On jobs without authored ordinary wolves, a separate background-pack roll rises
from 10% to 45%. Those wolves inhabit the world from the start. Thus the encounter
percentage is not the overall probability of any optional danger.

Pack size is independent of quotas. Each generated pack has an 8% large-pack roll
at wave 1, rising to 55% at wave 30. Large packs contain 5–7 wolves early and up to
5–12 late. Smaller groups also grow, and several packs can coexist. Pack generation
caps total wolves to control workload. Raider events grow from one attacker to
five solo (six with teammates). From wave 18, bear events have a 35% chance of a
second bear. Authored threats remain as well.

Werewolves have upright articulated bodies, claws and fast charges. Their close
warning is 0.7–1.1 seconds; ordinary wolves retain longer snarling warnings. Hunters
and raiders wear layered wilderness clothing and have jointed movement animations.
Bears warn, charge and injure; raiders investigate sound, seek cover while reloading
and can fight predators. Brain/heart hits are fatal when a projectile reaches the
actual organ volume. Side and front X-rays share the same trajectory.

Season, hour, terrain positions, cabin selection, animal profiles and event timing
vary. Every fifth round is midnight with a red full moon. The existing lycanthropy
system remains active. Wolf stat escalation is capped at the existing level-12 profile;
later difficulty comes from the expedition and its combined dangers.

Completing a round awards 40 + 8 × wave credits, in addition to hunting earnings.
This is an initial playable balance pass. Automated completion proves progression
and mechanics, not that the entire campaign's difficulty has been calibrated by humans.

## Verification

`tests/test_campaign.gd` checks all 30 jobs, onsite discoveries, automatic completion, vital hits,
each surprise type, spoiled meat replacement, victory and wallet-preserving death.
`tests/test_campaign_runtime.gd` exercises active bear/raider combat and can capture
native renders with `-- --capture`. `tests/test_campaign_coop.gd` runs three separate
processes to verify shared discoveries, survivor completion, kill-only hunts, revival and
new enemy replication. `tools/run_campaign_network.py` runs that test with isolated saves and a separate test port.

Test artifacts and current results are in `qa/campaign/` and `qa/campaign-*.log`.
Public-internet connections, a physical controller and a complete human 30-round run
remain outside this automated validation.
