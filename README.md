# Wolf Island — Godot FPS

**[Download the Windows game](https://github.com/Vividly4829/wolf-killer/raw/refs/heads/main/releases/windows/WolfIsland-Windows-x64.zip)** — extract the ZIP and run **WolfIsland.exe**. No Godot installation is needed for this build. [Build details and checksums](releases/windows/README.md).

Roman legionary patrols can now roll as optional surprise encounters from **level 11** onward. They begin with six soldiers and grow with campaign level and extra hunters (up to twelve). A warning precedes their arrival. They advance three abreast, then spread around their target at sword range. Raised shields stop low-penetration frontal torso shots; head, legs and flanks stay exposed, and heavy penetrating shots can punch through with reduced damage. Each soldier carries a red shield and short sword, uses human vital anatomy, and awards the existing human-enemy bounty. Their arrival does not change the main mission quota. Local/online co-op uses the host's combat decisions and replicated models, attacks and deaths.



A native Godot 4 first-person survival game on the existing Bremnesvegen 96 / Hestavikholmen island model. Every wake rolls a season and hour: spring/summer greens, autumn foliage or winter ground, with changing daylight and night lighting. The 30-wave campaign mixes hunting, exploration and dangerous expeditions. Every fifth wave forces a reddish full-moon night with one to three werewolves. See [the campaign guide](CAMPAIGN.md). The wolves retain their individual builds and coats, with sharper fur shading. Animated smoke rises from the real chimney; the cabin has an animated wood-stove fire, warm flickering light, textiles and steaming coffee. No artwork, sounds or game assets from The Long Dark are included.



The surrounding Nautøy mainland, neighboring cabins and docks, southern islet and road bridge are aligned using official map/elevation data and saved aerial and sales photographs. Twelve fictional timber crossings connect the starting island, western mainland, southern cabin island, northern shore and outer skerries. Their walkable decks and coastal navigation are game-only additions; the original island GLB, source terrain JSON and as-is Blender model remain untouched. Wolves can pursue across these routes. Gold lines mark the crossings on the expanded minimap. Restart an already running game to load changes.



Every fired shot opens a nonblocking, four-second X-ray review with an adjacent 3D slow-motion replay. Press **X** to reopen the latest shot; press it repeatedly to browse the last **32 shots**, including misses. Controller players use **D-pad down**. Original simplified anatomy includes the brain, spine, heart, separate lungs, liver and existing individual leg zones. The bottom-right review now shows simultaneous SIDE and FRONT anatomy views for wolves, wildlife, bears, hunters, raiders and werewolves, with injured organs and the same shot path from two angles. It lists weapon, distance, base damage, range factor, placement multiplier, calculated damage and actual health lost; misses are identified. Angle, animal size, remaining weapon damage and penetration affect which organs are reached. Penetration budgets vary from 22 cm for a knife to 115 cm for heavy rifles, scale down with distance, and stop at the first body exit. The report lists tissue travel. Brain and heart zones are separate small volumes: a side head shot cannot also claim a chest hit. Shotgun pellets may hit different zones, and the review filters each skeleton to a single target. Organ wounds alter damage and bleeding, spine hits impair movement, and limb wounds retain the existing limp/sever mechanics. This is a stylized game system, not a medical simulation. Shotguns retain individual pellet arcs; projectiles report on impact, even if another shot has since been fired. Firearms now use gravity-aware segmented collision traces, so drop changes where bullets hit. Lasers remain straight. The trajectory graph removes the launch angle and magnifies vertical drop relative to the dashed aim line, keeping downhill shots readable.



## Play



Install **Godot 4.6.2 Standard** from [the official Godot download page](https://godotengine.org/download/archive/4.6.2-stable/), import `project.godot`, and press **F5**. The repository contains the game source and required assets; Godot creates its import cache on first opening. Click **Wake in the cabin** to capture the mouse.

On Windows, **[Play Wolf Island.cmd](Play%20Wolf%20Island.cmd)** imports changed assets and launches the game. It uses a portable Godot 4.6.2 engine in `tools/` when present, otherwise `GODOT_BIN` or `godot`/`godot4` on PATH. Engine executables are excluded from Git. **Open in Godot.cmd** uses the same engine discovery to open the editor. No .NET runtime is needed.

The main menu has **Starting Level (1–30)** and **Starting Credits** fields. Type a number or use the arrows before waking, hosting, or starting local split screen. The displayed starting credits replace the wallet for both local hunters. Joining online follows the host's level and starting-credit setting, applied once when joining. Typed values are committed when Start is pressed, even without Enter. These settings apply to a new expedition, not death retries: death still restarts at level 1 and keeps the remaining money. Free Play remains its separate all-weapons mode.

The game opens fullscreen at your monitor's native resolution, with 100% 3D render scale. On a 4K display this is 3840 × 2160; local split-screen renders each hunter at 3840 × 1080. The interface scales separately to stay readable. **F11** toggles windowed/fullscreen mode, and split-screen camera resolution follows window resizing.



To edit the game, double-click **[Open in Godot.cmd](Open%20in%20Godot.cmd)**, or import **[project.godot](project.godot)** in Godot 4.6.2. Press F6/F5 to run the main scene/project. This is a separate native game; the earlier browser game and original Blender model remain available.



Standing eye height is **1.78 m**, with **2.85 m/s walking** and **6.075 m/s sprinting**, before terrain or injury modifiers.

The southern rock stub now crosses onto the mainland, creating a loop. The longer south-island bridge also has bank approach ramps at both ends.

## Rules



- Wake safely inside the cabin with a single-shot Frontier Musket. The opening line remains a text-only subtitle. Leave shelter to begin the mission. Starting enemies occupy reachable areas away from hunters; surprise encounters provide a warning before entering at a distance.

- The musket fires one powerful shot, then needs a **1.08-second reload**: pour powder, load a ball, ram it home, and cock the hammer. **Only reloading the musket stops walking, sprinting and new jumps**, while you can still look around. Other weapons allow movement during reloads. Switching weapons cancels an unfinished reload and restores movement. Every shot requires a fresh trigger press. Purchased weapons remain available until death; every new attempt begins with the musket.

- Levels 1–3 require hunting one deer, two deer, then a water goose. Optional danger can now occur even in these opening hunts. Level 4 asks you to kill any two wolves, with at least six available across three independent groups. All eligible wolves are marked on the map; you choose which group to hunt. Co-op retains its extra-player quota scaling and also adds spare targets. Later missions follow the authored [30-wave campaign](CAMPAIGN.md), with a dangerous surprise chance rising from 25% on wave 1 to 85% on wave 30, including blood moons. Background packs are rolled separately. Wave 30 is the finale; there is a victory screen instead of endless automatic escalation.

- New hunters start with **350 credits**. Existing saves receive a one-time top-up to 350 if below that balance; larger wallets are preserved. Spent money is not replenished by restarting. Both split-screen HUDs display their own wallet. Defeating a wolf earns **25 credits**, saved immediately.

- Every cabin has steaming coffee. Approach its cup and press **C / controller D-pad right** to restore **30 HP**, with a **20-second refill per hunter per cabin**. Drinking does not remove wounds.

- All pack-finding, cache and cabin-search objectives have been removed. Hunts and combat objectives count on the kill. Finishing all objectives automatically starts bed recovery, with no carrying or return trip. Bed recovery restores health, ordinary injuries, ammo, stamina and two bandages. Each subsequent job begins after leaving shelter. Simply standing in shelter does not heal you or erase threats; first aid purchases are unavailable during active missions.

- Every enterable building has a **Supply Store**, marked gold on the minimap. Press **E / controller Y** indoors or at the original outdoor counter. Browse **27 period and experimental weapons** in a scrollable catalog, filter by family, and drag the selected weapon's lit 3D preview to inspect it. The store shows prices, period, capacity, damage, reload duration and ammunition. Buy or equip the selected weapon, refill carried reserves, or purchase full first aid for **40 credits** between missions. Solo play pauses while shopping; multiplayer continues.

- If you die, you **lose all purchased weapons** and the next attempt starts at **level 1 with the free musket** inside the cabin. **All unspent money is kept**, along with your best level and total kills. Weapon loss is saved immediately, so restarting the game does not restore them. You can buy replacements at the store.

- Carry **three throwing knives** (0.22-second release interval, 32 m/s) or **one hunting spear** (30 m/s, 160 base damage). These have no hidden reserves. Store ammunition refills restore the carry limit; bed recovery also replenishes them.

- Ammunition reserves are **finite**. Store refills charge for missing reserve rounds at **1–6 credits each**, across all owned weapons. Refills do not load weapons: reload normally. Bed recovery and new attempts replenish ammunition. Wolves become tougher and faster in later levels. Shooting is blocked by solid island geometry. Water and steep ledges are outside the walkable area.



The pack acts as hungry, persistent predators. Wolves begin roaming and detect you through a forward view, line of sight, movement noise, gunshots and warnings from nearby packmates. Crouching reduces visibility and noise; sprinting and firing make you easier to find. After losing contact they search the last known location, then return to roaming. Required targets remain on the map; optional threats are not marked as objectives.



Every wolf is an individual adult: **six natural coat families**, varied size and build, and its own health, movement, bite strength, boldness and senses. Traits are rolled once when it spawns. Rare, especially large adults are tougher and hit harder, with a modest agility tradeoff; coat color does not determine combat strength. Strength also affects mauling damage and how hard it is to escape a struggle. Calls vary in pitch. Models, hit areas and detached limbs match each animal's size.



The pack's **alpha** is an experienced leader. It helps initiate approaches and nearby flanking, with a warning that carries farther. Leadership adds no health, size or damage bonus. Losing a leader can make nearby witnesses hesitate, back away or call before regrouping. Bolder wolves can stand their ground, and an attacker already mauling you remains dangerous. The response temporarily disrupts coordination rather than granting the entire pack a revenge damage boost; a surviving adult can later take over leadership. Aim at a visible wolf to identify its coat, size class and alpha status. Solid walls block identification. Alpha kills still earn 25 credits.



Wolves first snarl and circle for at least four seconds on a close encounter before they can rush or bite. A distant alert cannot use up that warning. Wolves give positional barks, growls and long howls, approach from separate angles and take turns committing to short rushes. At most two rush at once, with staggered starts; the others keep approaching or flanking. Flanking positions adapt to visible movement and facing, without a synchronized orbit around the player or knowledge of hidden health and reload timers.



Gunfire and nearby injured or killed packmates cause brief, local caution. Survivors reposition and renew their attacks, and a lone wolf is more cautious but still dangerous. These behaviors are stylized for the game's hungry-pack premise rather than a biological simulation. The cabin interior remains a sanctuary. Wolves cannot enter it, but **the terrace and the strip immediately outside the doorway are dangerous**: the navigation clearance around the house does not grant the player immunity.



Field-research references and the distinction between real family-pack leadership and the game's encounter mechanics are documented in [wolf behavior and variation](docs/wolf_behavior.md).



## Armory



All designs predate 1890. Each has an original procedural model, distinct action geometry and staged reload animation. The crossbow launches visible bolts with travel time and drop; the LeMat has a separate central shot barrel selected with **V**. These are stylized historical inspirations with fictional balance values, not exact replicas. See [historical references and date notes](docs/armory_history.md).



| Weapon | Period / model | Price | Loaded + reserve | Reload |

| --- | --- | ---: | ---: | ---: |

| Frontier Musket | 1777 | Free | 1 + 14 | 1.08 s |

| Hammer Coach Gun | 1878 | 450 | 2 + 14 | 2.00 s |

| Winchester 1873 | 1873 | 1,100 | 12 + 24 | 3.17 s |

| Hunting Crossbow | c. 1650 | 120 | 1 + 12 | 5.5 s |

| Dueling Flintlock | c. 1790 | 90 | 1 + 12 | 2.40 s |

| Brass Blunderbuss | c. 1780 | 220 | 1 + 10 | 2.80 s |

| Allen Pepperbox | 1837 | 200 | 6 + 18 | 4.67 s |

| Colt 1851 Navy | 1851 | 380 | 6 + 18 | 5.33 s |

| Remington 1858 | 1858 | 530 | 6 + 18 | 4.67 s |

| LeMat Revolver | 1856 | 800 | 9 + 18 | 6.33 s |

| Remington Derringer | 1866 | 150 | 2 + 12 | 1.60 s |

| Colt Single Action | 1873 | 700 | 6 + 18 | 3.00 s |

| Schofield Revolver | 1875 | 900 | 6 + 18 | 1.83 s |

| Snider-Enfield | 1866 | 600 | 1 + 12 | 1.43 s |

| Martini-Henry | 1871 | 850 | 1 + 12 | 1.27 s |

| Sharps 1874 | 1874 | 1,250 | 1 + 10 | 1.50 s |

| Spencer Carbine | 1865 | 1,000 | 7 + 21 | 2.50 s |

| Winchester 1887 | 1887 | 1,500 | 5 + 15 | 3.00 s |

| Throwing knives | traditional | 8 | 3 + 0 | Ready; 0.22 s between throws |

| Belt axe | traditional | 16 | 1 + 8 | 1.8 s |

| Hunting spear | traditional | 24 | 1 + 0 | Ready; single throw |

| Ash self bow | traditional | 35 | 1 + 16 | 2.6 s |

| Yew longbow | traditional | 75 | 1 + 16 | 2.6 s |

| Horn recurve bow | traditional | 110 | 1 + 16 | 2.6 s |



Thrown weapons have short range, pronounced drop and wide dispersion. Bows trade price for speed, accuracy and damage. Knives, axes and bows reward precise vital-organ penetration; the single carried spear has 160 base damage. All use travelling projectiles; ammunition is finite. They are thrown/fired weapons, without a separate melee mode.



The LeMat's central barrel additionally carries one shot charge and four reserve charges, with a 2.83-second reload. Injury can lengthen reloads. Higher prices buy different strengths and tradeoffs; ammunition, reload time, recoil and effective range still matter.



Quick keys follow your **owned inventory order**, not the store's catalog numbers: buying the crossbow first makes it quick key **2**, even though it is design **04**. The equipped HUD and owned store entries show the actual key. Use Q or the wheel for weapons beyond the ninth owned slot.



## Wounds and recovery



- Wolves have separate head, body and leg hit areas. Headshots deal extra damage; injured legs produce a limp, slower movement and blood loss. Severe leg wounds can detach the actual leg, leave a visible stump and cause fatal bleeding. Credits are awarded when the wolf dies, including death from blood loss.

- Combat includes stylized dark red blood bursts, ground splashes, trails, detached limbs and fallen wolves. Effects and corpses have population limits and timed cleanup.

- Bites can cause bleeding, leg injuries, arm injuries and concussion. Bleeding continues inside shelter until treated. Leg injuries reduce movement and jumping; arm injuries make aim less steady and reloading slower; concussion briefly disturbs the view and gradually fades.

- A wolf can grab you in a close struggle. **Hold F or the left mouse button** to fight it off; you cannot shoot or move normally while grabbed. A percentage and filling bar show escape progress for each hunter, including split-screen. Controller players hold **RT**. Breaking free briefly prevents another grab.

- Press **B** to apply one of your two bandages. The 2.4-second action stops bleeding, but leaves other injuries. Store first aid costs 40 credits between missions; active expeditions allow coffee for HP, bandages for bleeding, or finishing the round for full recovery. Completing the wave restores everything during bed recovery.



| Control | Action |

| --- | --- |

| W A S D | Move |

| Mouse | Look |

| Left mouse | Fire once per press |

| Right mouse | Aim / zoom |

| Shift | Sprint while stamina lasts |

| Ctrl | Hold to crouch and move quietly |

| Space | Jump |

| R | Reload |

| B | Apply a bandage to stop bleeding |

| C | Drink nearby cabin coffee (+30 HP) |

| Hold F or left mouse | Fight off a grabbing wolf |

| E | Open nearby store |

| 1–9 | Equip the corresponding owned quick slot |

| Q / mouse wheel | Cycle all owned weapons |

| V | Switch the LeMat between cylinder and central shot barrel |

| Enter | Start next level during preparation, while outdoors |

| Escape | Pause / resume or close store |

| F11 | Toggle fullscreen |



Solo play pauses when it loses focus. In multiplayer, the world continues while a hunter pauses or shops.



## Three-player co-op



Choose **Host 3 Player**, or enter the host address and choose **Join**. Everyone needs this game version. Use the host computer’s local address on a LAN. Over the internet, the host needs reachable **UDP port 27896**, usually with a router port-forward/firewall rule, or a shared VPN. There is no public matchmaking service. Three separate local processes have been tested; a public-internet session has not.



The host runs the animals and resolves shots. Friendly fire is enabled outdoors. Rewards are shared. The host starts in the original cabin; the second and third hunters spawn in two different neighboring buildings. Each hunter returns to their assigned building on every round. A fallen hunter waits while surviving teammates continue the objective. Completing the main objective revives and heals everyone for the next round. Only a total team wipe resets the shared run to level 1. Death removes that hunter’s purchased weapons but preserves their saved wallet; survivors keep their weapons. Neighboring buildings remain accessible to wolves. Friendly-fire hits show a human bone X-ray with the bullet path, injured organs, placement multiplier and actual health lost. Host/join is intended for friends, not competitive anti-cheat play.



The cabin’s front and new back door open on approach and close automatically. Shooting is disabled inside. There is no crosshair or centre hit marker: use the weapon’s physical sights and right-mouse aiming.



The world contains surplus deer, ducks, geese and mink on every mission. Predators may hunt them. Orange map markers show current required animals and supply caches and cabin search sites; green marks home. Wildlife rewards remain available outside the quota. Hunter kills count immediately toward hunts, including grenade, dynamite and grenade-launcher kills. Missing prey is replenished so predation cannot permanently block progress.



## Saved progress



Money and current weapon ownership live in `%APPDATA%/Wolf Island/progress.cfg`. Closing the game while alive keeps your purchased weapons; death clears them while preserving your money and records. The previous save is kept as `progress.cfg.bak`; updates use a temporary file before replacing the active save. Level state is deliberately not saved: entering the island starts a new attempt at level 1. Automated tests use separate save files and do not change player progress.



## Source and assets



The Godot project includes the wolf model, island and navigation data from the existing browser game. The active island treatment uses native shaders with broad painted colors and procedural leaf geometry; it does not display the bundled photographic ground textures. Godot's copy of the island GLB converts quantized normals to floating point; vertex positions, colors and original source files are preserved. `tools/prepare_island.py` reproduces this conversion. The store and dressed recovery bed are additional game props. Both actors use the sampled 25 cm navigation grid for terrain, wall and step clearance; wolves use a separate field excluding the cabin. Bullet raycasts use Godot's physics engine.



Scripts separate game state, saved progress, HUD, island, player, wolves, weapons and synthesized sound effects. Main scene: `scenes/main.tscn`. The opening line is bundled synthetic speech generated offline with an installed Windows voice; it plays without a speech service or internet connection. `tools/build_voice.ps1` reproduces it. Environment, animal and audio attributions are in `assets/environment/README.md`, `assets/environment/sources.json`, `assets/foliage/CREDITS.md`, `assets/WOLF-CREDITS.md` and `assets/audio/CREDITS.md`. Godot's license and verified engine source are in `tools/`.



Wolf howls use a public-domain National Park Service field recording from Denali, with restrained pitch variation and positional distance filtering. A dedicated emitter and a 14–21 second gap between calls prevent a large pack from stacking the recording into a continuous chorus. Firearms use original 48 kHz layered gunshots generated by `tools/build_gunshots.py`, with three variations per family: a sharp crack, heavy blast and outdoor echo. Dedicated playback pools preserve gunshot tails during pellet impacts and animal calls. Local reports use a stronger mix; nearby co-op shots and raiders are positional. A shared peak limiter handles simultaneous shots. Barks, growls, reload, impact and wind remain original stylized synthesis in `scripts/soundscape.gd`. Animal calls use spatial emitters so their direction and distance matter. See `assets/audio/CREDITS.md` for the howl's source and usage terms; no commercial-game audio is included.



## Design references



The [user-provided gameplay video](https://www.youtube.com/watch?v=0NhAwtDiPCQ) is a design reference. Hinterland's official [Steadfast Ranger update notes](https://www.thelongdark.com/news/steadfast-ranger-update-now-live/) document an accessible struggle option with tap or hold input. Wolf Island uses inspired mechanics and an original implementation, rather than a faithful reproduction of The Long Dark.



## Verification



From this folder in PowerShell, set the engine executable once. For example:

```powershell
$godotExecutable = if ($env:GODOT_BIN) { $env:GODOT_BIN } elseif (Test-Path './tools/Godot_v4.6.2-stable_win64_console.exe') { './tools/Godot_v4.6.2-stable_win64_console.exe' } else { 'godot' }
```

The commands below use that value. Generated captures and test logs are local outputs and are not committed.



```powershell

& $godotExecutable --headless --path . --editor --import --quit

& $godotExecutable --headless --path . --script res://tests/test_progress.gd

& $godotExecutable --headless --audio-driver WASAPI --path . --script res://tests/test_howl_audio.gd

& $godotExecutable --headless --path . --script res://tests/test_game.gd

& $godotExecutable --headless --path . --script res://tests/test_armory.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_player_weapons.gd

& $godotExecutable --headless --path . --script res://tests/test_weapon_visuals.gd

& $godotExecutable --headless --path . --script res://tests/test_wolf_profiles.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_wolf_variants.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_wolf_pack_game.gd

& $godotExecutable --path . --fixed-fps 60 --script res://tests/preview_wolf_variants.gd

& $godotExecutable --headless --path . --script res://tests/preview_armory_store.gd

& $godotExecutable --path . --script res://tests/preview_armory_store.gd -- --capture

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_actors.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_player_hunting.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_wolf_hunting.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_pack_behavior.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_encounter.gd

& $godotExecutable --headless --path . --fixed-fps 60 --script res://tests/test_survival_loop.gd

& $godotExecutable --headless --path . --script res://tests/world_smoke.gd

& $godotExecutable --path . --script res://tests/world_smoke.gd -- --capture

& $godotExecutable --path . --script res://tests/preview_survival.gd -- --qa

& $godotExecutable --path . -- --qa

```



The hunting tests cover player stealth/injuries and wolf perception, wounds and loss of contact. The pack test checks staggered commitments, multiple attackers, reactions to casualties and a lone survivor's renewed attacks. The encounter test walks from the cabin using real controller input and checks naturally spawned wolves, shelter safety, outdoor bites, the doorway, pursuit and defeat.



Wolf profile tests sample thousands of seeded adults to check variation, bounded traits, coat diversity, size-related tradeoffs and leadership without stat bonuses. The variant test exercises individual bodies and leader behavior. The pack/game integration test checks varied real spawns, alpha rewards, sight-based identification, strength-dependent struggles and persistent money. Hunting tests also verify that a severed leg keeps its source wolf's scale.



The survival integration test checks real body and limb raycasts, repeated mauling, held-input escape, paused struggles, bandaging, fatal bleeding saves, full bed recovery and walking from the bedside toward the exit. The survival preview renders wounds, a close struggle, resting and waking through the actual game's GPU renderer.



The armory integration test checks catalog purchase and ammunition rules, weapon cycling, the LeMat selector, crossbow projectiles and loss of equipment on death. Separate player and model tests cover input, reload movement and all 24 native weapon models. The store test checks all 24 inspection models, scrolling, family filters, affordable and unaffordable purchases, owned equipment and drag rotation. Its graphical mode captures the native 1280 × 720 store with representative long guns, crossbow and revolvers. Tests use isolated progress files.



The native performance playtest measures wall-clock frame times during actual controller movement, natural attacks, larger packs, sustained gore, all 24 store previews and held weapons, reloading, bed recovery, death and retry. It writes hardware/window metadata, mean FPS, percentile frame times, 1% lows, slow-frame counts, scenario checks and source fingerprints. It separates initial loading, authored stress-fixture setup and transitions from steady gameplay. It uses an isolated save and temporarily suppresses automatic focus-loss pauses only in the benchmark; deliberate Escape pauses still work.



```powershell

& $godotExecutable --path . --script res://tests/performance_playtest.gd -- --perf-output=qa/performance-local.json

& $godotExecutable --path . --script res://tests/performance_playtest.gd -- --perf-uncapped --perf-resolution=1920x1080 --perf-output=qa/performance-local-1080.json

& $godotExecutable --headless --path . --script res://tests/test_weapon_model_cache.gd

& $godotExecutable --headless --path . --script res://tests/test_spawn_selection.gd

```



Do not add `--fixed-fps`, `--headless` or `--qa` to performance runs: they alter timing, disable rendering or activate a separate scripted scene. Run benchmarks one at a time. The uncapped option changes VSync only for that test process. Detailed weapon geometry is cached during loading, inspection rendering resources are reused, and normal wave spawns avoid repeated full-island searches. Models, animation mechanisms and spawn safety rules retain their original detail and behavior.



The world smoke test checks reachable terrain, the exact cabin safe zone, an open exit and bed aisle, the chimney location, plus gore population limits, expiration and clearing. Its optional graphical mode writes native GPU screenshots of the moonlit cabin, shelter, bed and blood effects to `qa/`. The final command runs gameplay visual QA and exits after its screenshots. It bypasses focus-loss pause only during QA. The corruption-recovery test intentionally prints a ConfigFile parsing error before passing.



Current update checks and native screenshots: [September 20 playtest update](qa/feedback-update/README.md).


## Slower survival movement, looting and lycanthropy

Walking is 2.85 m/s, sprinting 6.075 m/s and crouching 1.25 m/s, with gradual acceleration and gentler head bob. Sprinting takes priority over holding aim: it lowers the weapon, removes zoom and applies a minimum wide hip-fire spread. Musket reload immobilization remains unchanged. Bush patches reduce player and wolf movement to 55% of normal speed; crossings and entrances are kept clear of shrubs.

The six mapped neighboring cabins/outbuildings have game-only open entrances, interior floors and access steps. Wolves can follow you inside; only the original starting cabin is a sanctuary. Press **E / Xbox Y** beside visible weapons to collect them without paying. Each wake refreshes each building's pickup: a cheap throwing weapon/self bow normally, or an 8% chance of a better period weapon. Pickups are shared in co-op and can be claimed only once per wake. Duplicate weapons refill ammunition. These fictional interiors and runtime terrain adjustments do not edit the source as-is model or GLBs.

Original procedural ambient music uses sparse bowed tones and struck notes, blending gradually into a dissonant tension layer when any living wolf is alerted. Chase growls, fabric/flesh tearing Foley and a stylized synthesized pain cry accompany bites. No commercial game music or recorded actor performance is included.

A werewolf bite causes lycanthropy: **50% faster movement immediately**, persistent red-tinted vision and no blur. After completing the next fifth-wave werewolf round, maximum health becomes **200 permanently for that run**, including ordinary rounds. Example: bitten on wave 5, survive wave 10, wake on wave 11 with 200 HP. The condition avatar and co-op character become werewolf-like. Bed recovery and medicine do not cure lycanthropy; restarting the run clears it. The curse belongs to the hunter bitten.

Current checks and screenshots: [survival expansion QA](qa/survival-expansion/README.md).

### Opening hunts

Level 1 requires one deer, level 2 two deer, and level 3 a goose swimming near the southern crossing. There are no wolves in these three levels. Extra targets spawn so the mission never depends on a single animal. Completing each hunt retains the bed-recovery transition; solo death or a total co-op team wipe resets to level 1 while keeping money. The fifth-level full-moon event remains on level 5.

Deer notice close approaches, see standing hunters farther away than crouched hunters, and hear loud movement and gunshots. Fear lasts after the sound stops. Nonfatal shots trigger flight and bleeding, leaving bounded blood spots along the route. A wounded deer can bleed out; its death still awards the hunter and counts toward the current deer objective. Wrong-species kills do not advance it. Co-op uses shared objective progress and host-authoritative wildlife.

## Shooting range and Free Play

Choose **FREE PLAY / ALL WEAPONS** on the main menu to start at the new shooting range on the western mainland. It is also present in the campaign, marked cyan on the minimap and connected to the coastal walking routes. The three timber-backed targets have unobstructed lanes at roughly 8, 16 and 24 metres. Hits show a ring score, hit count and estimated weapon damage in the shot review.

Free Play equips all 27 weapons. Use **Q / mouse wheel** to cycle, **1-9** for owned quick slots, and **R** to reload. Reserves replenish automatically; **R** restocks practice knives/spears to their normal carry limit. Normal magazine capacities, reload times, musket immobilization, projectile drop and the sprint firing lock remain active. Deer, birds, mink and three non-hostile wolves populate the practice area and refresh every 60 seconds. They do not start wave objectives or attack the player. Practice animals can be shot to inspect hit zones.

Free Play is a solo sandbox. Its inventory and earnings exist only in memory, with disk saves disabled. Returning to the menu restores the campaign wallet and owned weapons. It does not unlock weapons in the campaign.


## Playtest polish

The first hunt now populates ten deer and ten other animals. Nearby targets keep the opening hunt approachable, while additional wildlife roams the connected map. The quota remains one deer. Firearm aiming aligns the front and rear sights with the camera; loaded hammers sit cocked clear of the sight line. Larger leather-gloved hands replace the small bare hands. Walking heights interpolate over connected ground, match bridge slopes, and follow smooth house approaches with solid stair risers. See `qa/playtest-polish/README.md` for validation.


## Hunting and co-op upgrade

Mission animals now remain orange on the map, including unseen wolves and the current deer/goose targets. Deer prefer roomy ground for spawning and escape destinations. Individual escape headings, destination spacing and nearby-animal separation prevent shoreline stacking. Wildlife takes connected local exits first, uses bounded A* around enclosed obstacles, and remembers blocked goals when rerouting. Speed accelerates while direction follows corners without sliding into the shore. Goal selection is staggered across physics frames. See `qa/deer-shore.md` for regression tests.

Direct brain or heart trajectories are immediately fatal for wolves, deer, ducks, geese, mink and human hunters, regardless of weapon damage. Other hits still use ordinary damage and bleeding. Each species has a bone/organ X-ray, and reports identify fatal vital hits. Substantial nonfatal damage (30% of maximum health) causes a fall and recovery; lighter hits flinch. These reactions and corpses replicate online.

The armory now has 27 weapons. Iron grenades cost **85 credits**, with a 2.8-second fuse and 6 m blast radius. Dynamite costs **140 credits**, with a 3.5-second fuse and 9 m radius. Each purchase provides exactly one throw, no reserve; after use it must be purchased again. Blasts respect solid cover and can hurt the thrower and other hunters. The explicitly fictional **Aether Crank Musket** costs **6,000 credits**: five laser shots followed by a **12-second crank recharge**. Free Play includes the new weapons.

Sprint capacity is **300**, three times the original 100. Jump with **Space**. The first-person hands now use an original continuous adult grip mesh, generated by `tools/build_adult_hand.py` in Blender, rather than separate spherical palms and finger rods.

### Local two-player split screen

Choose **LOCAL SPLIT SCREEN / 2 PLAYERS**. Both hunters start immediately in their assigned buildings after the map loads. Player 1 always uses keyboard/mouse in the upper view; player 2 always uses the first connected controller in the lower view. There is no host/join step, IP address, port, connection screen or additional Start/A press.

Player 2 retains a separate saved wallet (`progress_local_controller.cfg`). Each hunter has independent inventory, injuries, X-ray and a building assignment. Friendly fire, shared objectives, survivor completion, round revival and team-wipe restart remain active. The views exchange gameplay state directly inside the game process, without network sockets. A controller can be connected after starting; player 2's view remains ready and displays a connection reminder.

Split screen is strictly local and cannot host or join online players. **HOST 3-PLAYER CO-OP** and **JOIN** remain separate, single-local-player online modes.

Xbox controls work in solo and online play as well as split screen. Outside split screen, pressing a controller button or moving a stick activates that controller; using a keyboard key or mouse button switches back. Disconnecting the controller restores keyboard control. Split screen keeps the upper keyboard hunter and lower controller hunter separate.

Controller: left stick move, right stick look, LT aim, RT fire/hold to struggle, **A jump**, hold L3 sprint, hold B crouch, X reload, **Y pick up / search / open store**, **LB/RB previous/next owned weapon**, D-pad up bandage, left LeMat selector, down browse X-ray history, Menu/Start pause/resume. In the shop: **D-pad up/down browse**, **A buy/equip**, X ammunition, D-pad right first aid, **B or Y leave**, LB/RB category, right stick rotate preview. Browsing automatically scrolls the selected weapon into view and respects the current category. At the death screen A retries; from pause A/B resumes and Y leaves the session. Prompts show the active input device.

Validation and limitations are recorded in `qa/hunting-upgrade/README.md`. Restart the game after updating.

## Starting split screen

Restart the game after updating. Connect the Xbox controller, choose **LOCAL SPLIT SCREEN / 2 PLAYERS**, and play: top is keyboard/mouse, bottom is controller. Player 1 never switches to the pad while in this mode. See `qa/split-local-only.md` for validation. Earlier QA about online-plus-split describes the retired implementation.

## Expedition danger and handling update

Werewolves now have an original upright, articulated silhouette with a muzzle, claws and fur tufts. They approach at 4.8 m/s and can charge at 11.5 m/s before terrain/injury modifiers, with a short 0.7–1.1 second close warning. Ordinary wolves retain their longer snarling warning. Hunters and raiders wear layered coats, boots, caps and packs, with jointed walk, crouch, aiming and attack animations.

Wolf pack size is independent of the mission quota. The large-pack roll rises from 8% to 55%; early large packs contain 5–7 wolves, rising to 5–12 late in the campaign. More than one pack may be present.

Bush slowdown now blends smoothly from full speed to 68%; navigation slides along nearby clear tangents and the camera smooths ground height changes. Solid trunks, walls and cliffs still block passage.

Bows have less random spread and a physical brass sight bead, zeroed at 20 metres. Aim higher beyond that distance and lead moving animals. No HUD crosshair was added. Range instructions now sit beside the firing lane.

Grenades and dynamite remain armed after landing or reaching their travel limit. Their fuse triggers area damage, fire/smoke, a boom and nearby camera shake. Each purchase is still one use, and blasts can hurt hunters. Being shot causes bleeding, impact blood, screen-edge blood, camera shake and recorded pain vocals. Audio source and license: [HaelDB pain recordings](assets/audio/PAIN_AUDIO_LICENSE.md).

## Shot replay and spare guns

Each completed shot plays a **four-second 3D trajectory reconstruction** beside
its X-ray. The camera follows the recorded projectile samples and timing, including
misses and shotgun pellets, with struck anatomy placed at the recorded impact pose.
This is an isolated flight reconstruction, not a video of the live world. Combat
continues at normal speed. A new shot replaces the current replay; **X / D-pad down**
replays older shots. Arrows wait for the complete flight, then replay for four seconds.
The replay pauses with solo menus and stops rendering when hidden.

All firearm reload times are one third of their previous values, including the
LeMat secondary barrel and aether musket crank. Bows, crossbows and thrown weapons
retain their previous reload times. The store shows the current durations.

Owned guns now have a **Buy Another** button (controller **R3**). Each copy is a
separate inventory slot with its own loaded ammunition; Q/wheel, LB/RB and numbered
slots switch between copies. Copies of a model share reserve ammunition, and each
purchase adds its included reserves. LeMat secondary barrels are independent too.
The HUD identifies the equipped copy. Copies save with the inventory, refresh after
a round, and are lost on death as before. Genuine player friendly fire is still
labelled; werewolf hits no longer use that label.


## Armory and wolf-audio update — 21 September

The armory now has 31 designs. New entries: Lancaster four-barrel pistol (130 credits, four shots), Mauser C78 zig-zag revolver (480, six shots), Mauser Model 1871 bolt-action rifle (950, one heavy shot), and a fictional gold-plated naval pistol pair (1,850, two heavy shots). The Mausers preserve the pre-1890 setting. The naval pair fires right then left, with separate muzzle flashes and iron-sight alignment; reloading both resets to the right hand. Existing three-times-faster gun reloads apply to these guns too.

The aether musket fires a thick red beam with a bright core and a fading outer glow, from its visible muzzle. Its reload is four seconds.

At any store, **Unequip / Re-equip** stores or carries every copy of the selected design without selling it or losing its loaded ammunition. Stored designs are skipped by weapon cycling and quick selection. Keep at least one design carried. On Xbox controller press **L3** to toggle the selected design; **R3** buys another copy. Death still removes purchased weapons, including stored ones.

The host now releases stale wolf struggles when the victim reaches safety or the attacker dies/disappears. Wolves also invalidate stalled routes and attempt a sidestep when navigation yields no direction. Small and large wolves were checked leaving all six neighboring buildings.

Mauls use three human cries, four recorded canine snarl variations, and four recorded cloth tears. A dedicated scream player prevents repeated bites from cutting off the voice. The old electronic hurt pulse no longer plays under bites. Existing real wolf howls remain, and peaceful music is 5 dB louder. Recording sources and licenses are in `assets/audio/MAUL_AUDIO_LICENSE.md`.

Historical design references: [Lancaster research, American Society of Arms Collectors](https://americansocietyofarmscollectors.org/wp-content/uploads/2022/04/1992-B66-Lancaster-Multi-Barrel-Pistols.pdf) and [Mauser C78, Smithsonian](https://www.si.edu/object/mauser-c78-zig-zag-revolver%3Anmah_414535). Weapon geometry is original and stylized; handling and prices are game balance.


## Combat feedback update

Animal deaths, knockdowns and severed wolf legs are applied explicitly to co-op replicas, including when their physics is disabled. Nearby living animals appear within 75 m: red hostile, blue panicked, pink calm. Mission targets retain their map rings outside that radius. Bears growl on engagement and during pursuit; wolf warning vocals are louder.

Round 6 has a whole-round ordinary wolf budget of four solo or five with two hunters. Early packs normally contain two or three wolves; later encounters still escalate. Werewolves have at least 420 HP (individual maximum health multiplied by 3.5, with a 420 minimum). A penetrating brain or heart hit is instantly fatal.

The four-second replay includes faint nearby static scenery and impact blood. Its trajectory graph adds the struck anatomy at the endpoint, using the same vertical scale as the arc; target width is deliberately enlarged for legibility. Original frontier-ranger outfits add goggles, dusters, leather equipment and articulated coat tails. The left field-condition avatar highlights actual injuries beside HP.

**F / controller R3** quick-throws the highest-damage carried spear, axe or knife with ammunition. Recovery is 0.24 seconds; your current gun and its ammunition are preserved. Stored weapons are excluded. During a wolf struggle F still fights the attacker; R3 in the store still buys another copy.

The catalog now contains 35 designs:

| Added design | Credits | Magazine |
|---|---:|---:|
| Twin blunderbusses | 1,100 | 2 |
| Paired frontier revolvers | 1,650 | 12 |
| Artillery Luger with drum | 6,500 | 32 |
| Experimental 1889 hand mortar | 2,800 | 1 |

The Luger is an explicit later-era exception requested for the premium armory; the 1889 launcher is a fictional period prototype. Dual weapons alternate hands and reset after a full reload. The launcher fires an arcing shell, detonates on its first impact, and retains the weapon after firing. Its blast can harm either hunter.


## Hunting and combat polish

Sprinting is now **6.075 m/s**, with **337.5 stamina** (both reduced by 25% from the previous build). You cannot shoot or quick-throw while sprinting. Raiders use bows, knives, axes and spears, with physical projectiles stopped by walls and close-range melee. Source-tagged non-solid foliage no longer blocks bullets; solid structures still do.

Grenades and dynamite display a live fuse countdown in both player views. Explosions produce larger fire/smoke clouds. Launcher shells explode immediately on impact. Cached dual-gun models preserve their wood, brass and steel materials.

Very close deer can briefly charge or strike before fleeing; this is an occasional defensive reaction, disabled in Free Play. Shot replay now includes up to eight nearby unhit animals at their recorded firing-time positions and frames the closest missed animal for context.

All animal types now support limb loss: ordinary wolves, deer, mink, bear and werewolf limbs, plus duck/goose legs and wings. Humans retain their existing injury behavior.


## Repository contents

This repository contains the standalone Godot game and all runtime assets. Some historical asset-rebuild notes and scripts refer to the original workspace's parent `game/`, `reference/` or Blender-model folders; those source-workspace folders are not part of this repository and are not needed to play. The source island model has not been modified. Keep the individual asset attribution files with redistributed assets. There is no blanket license grant for this project; third-party assets retain their documented licenses.

Recent focused checks: `tests/test_hunting_combat_polish.gd`, `tests/test_split_session.gd`, `tests/test_shot_replay.gd`, and `tests/test_legionaries.gd`. Older tests document earlier feature stages and may contain outdated expectations.


## Health-scaled animal limb loss

Damage accumulates separately in each struck limb. The severing threshold is `max_health * clamp(0.65 + max_health / 800, 0.65, 1.6)`, measured in limb impact damage (shot damage multiplied by the weapon limb-force factor). A higher-health animal therefore requires both more total limb damage and a greater fraction of maximum health. Examples: 18 HP wildlife ≈12.1 impact damage, 70 HP deer ≈51.6, 80 HP wolf 60, 260 HP bear 253.5, and a minimum-420 HP werewolf 493.5. Individual wolf/werewolf stats scale these thresholds automatically.

Only dedicated limb hits count toward these thresholds. Legs/wings disappear from the live model and collision, detached pieces fall, and wounds bleed. Surviving animals slow down; blood loss can finish them after a short interval. Repeated hits to one limb accumulate; hits to different limbs do not combine. Missing-limb state is replicated to co-op clients, including when an animal dies in the same update. Wildlife maximum health stays fixed as its current health falls, so nearly dead animals do not become artificially easy to dismember.

### Compact HUD and round rewards

The gameplay HUD is smaller by default, including the condition avatar, map and shot reviews. Hit and miss X-rays stay fully opaque. Animal hits show actual damage in large red text, per-animal red replay labels, and a varied flesh-impact sound for the shooter. Keyboard **X** restores larger HUD details for eight seconds and still cycles older shots; the X-ray and replay remain slightly smaller and anchored clear of the aiming area. **Double-tap X** within 320 ms to close the review and return to the compact HUD; controller D-pad down expands that player's shot review. Stores and menus retain their normal size. The round credit row lists gross rewards received by every connected player (P1–P3); purchases do not reduce it. It resets when the next round begins at the cabin or a new run starts. Shared rewards still go to every player.

## Gunfire, blast coverage and musketeer patrols

Firearms emit brief orange barrel flames and thin, fading smoke along their recorded bullet paths. Hits kick up soil, stone chips, wood fragments or leaves; nearby foliage briefly sways. These cosmetic effects are capped at 64 active groups. Split-screen and online clients receive the effects.

Explosives sweep a small sphere along their movement and check terrain seams, so fast grenades land on slopes instead of tunnelling through them. Timed grenades keep falling until they land or their fuse expires, even beyond nominal throwing range. The X-ray shows the actual blast radius, falloff ring and exposed/covered targets; the replay shows the radius in world space.

From wave 11, an optional Napoleonic-inspired musketeer platoon can appear. Soldiers wear navy coats and shakos, form ranks, raise muskets before firing staggered volleys, reload slowly and use bayonets up close. Their physical musket balls stop at walls. Existing raiders retain their bows and throwing weapons.

Validation: `tests/test_combat_world_fx.gd`, `tests/test_hunting_combat_polish.gd`, `tests/test_split_session.gd` and `tests/test_campaign.gd`.


## Weapon economy and field guide

All 36 purchase prices now sit between 25 and 1,000 credits. The spear is the cheapest at 25; the drum Luger is the most expensive at 1,000. Prices weigh practical reach, accuracy, capacity, reload downtime, stealth and crowd control. The starter musket is still granted at the beginning of a run; extra copies cost 125.

Budget fieldcraft and simple firearms cost 25–175; quiet precision weapons and revolvers occupy the middle; repeaters, heavy precision rifles and dual weapons cost more. Recurring explosives cost 275 for a grenade and 425 for dynamite. The launcher costs 900 and the rechargeable aether musket 950.

Grenades and dynamite remain owned after use, each with one carried charge and no reserve. They restore one charge free at the next round's wake, including co-op players. Switching, re-equipping or buying ammunition does not replenish them mid-round. Death still loses weapons. Free Play allows reloading them for repeated practice.

The main menu's **Weapon Stats & Prices** opens a six-page guide sorted by price. It reads live catalogue values for price, base damage/pellets, effective and maximum range, loaded/spare ammunition, actual reload time, shot interval, spread, penetration, noise and blast details. Use the page buttons or controller D-pad/LB/RB; Escape or controller B returns to the menu without discarding expedition settings.


## Psychedelic mushrooms and primitive fire siphon

Small red Amanita muscaria clusters with cream spots occasionally grow on navigable terrain. Approach and press **E / controller Y** to consume one. Each player can consume a cluster once per round; another player's pickup does not take yours away. **Psychedelic** lasts until the next cabin rest: highly vivid colours, species silhouettes for all living animals on both radar layouts, and **30% lower maximum HP**, with current HP capped immediately. Additional mushrooms do not compound the penalty. It stacks with lycanthropy: 70 HP before the permanent upgrade, 140 HP afterwards. Rest clears psychedelic and restores the usual maximum. The mushroom effect is a fictional game mechanic.

The **Primitive Fire Siphon** is a fictional brass, hand-pumped flame weapon costing **850 credits**. Hold left mouse / right trigger for flame pulses: 3 traces × 7 base damage every 0.15 seconds, 5 m effective reach, 10 m maximum, 60 fuel pulses loaded plus 120 reserve, and a 5-second reload. Fuel replenishes at round rest. Flames stop at walls, can burn other hunters, and cannot be fired indoors or while sprinting. The weapon has an original model, orange flame particles and a synthesised fire roar. It is available in stores, Free Play and the main-menu stat guide.

## Incapacitation and dark sacrifices

Animals and enemy NPCs with **more than 0 HP and at most 7% of maximum HP** become incapacitated. They stay down, stop moving/attacking and stop losing health to bleeding while awaiting a finishing hit or sacrifice. Zero-health bodies cannot be offered; players cannot be sacrificed.

Approach within 3 metres with a clear line of sight and press **E / controller Y**. A four-second ritual locks movement and firing, draws a rotating red pentagram and rising sparks, pulses red lighting and plays original ominous music. Taking damage, moving away, losing the victim or changing rounds interrupts it. The host validates co-op rituals and prevents two players claiming the same victim.

A completed sacrifice counts as a normal kill for mission progress and rewards. Only the performer receives its boon. Boons last for **three rounds including the current round**; the same type refreshes its duration, and different types stack. They survive cabin rests and clear on a new run. Active names and remaining rounds appear along the bottom of the HUD.

| Sacrifice | Status effect | Benefit |
|---|---|---|
| Deer | Hart's Vigour | 35% less sprint stamina use |
| Duck | Marsh Veil | 40% less movement noise for detection |
| Goose | Watchful Omen | All-animal radar with species icons |
| Mink | Shadow Step | 50% faster crouched movement |
| Wolf | Pack Hunger | 20% more weapon damage |
| Werewolf | Moon Blood | 25% more maximum health |
| Bear | Iron Hide | 20% less incoming damage |
| Raider | Sleight of Hand | 25% shorter reloads |
| Legionary | Unbroken Will | 35% faster struggle escape |
| Musketeer | Dead Eye | 30% less weapon spread |

Moon Blood stacks with lycanthropy and psychedelic: an empowered infected hunter has 250 maximum HP, or 175 while psychedelic. Increased maximum HP does not instantly heal the hunter; normal healing and rest can fill it.
