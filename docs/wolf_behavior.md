# Wolf variation and pack leadership

Wolf Island combines a fictional hungry-pack encounter with a few principles from field research. The island, combat values and short response timers are game design. The North American populations cited below are biological reference examples, not a survey of wolves around the Norwegian island.

## Biological references

Wild packs are commonly families whose breeding adults guide their offspring. Mech's field observations describe parental leadership and shared work; the popular image of a permanent “alpha” winning endless dominance fights is a poor default model. The game's **alpha** label means an experienced pack leader. [Mech, 1999, USGS publication record](https://pubs.usgs.gov/publication/1001725).

Leader loss can disrupt a pack, but its effects vary. In the Denali study's 94 analyzed breeder-loss cases, 63 packs persisted and 31 dissolved. Smaller packs were more vulnerable. These were outcomes across seasons; they do not establish an immediate combat response. An automatic revenge frenzy or guaranteed instant dispersal would overstate the evidence. [Borg et al., 2015, Journal of Animal Ecology](https://besjournals.onlinelibrary.wiley.com/doi/10.1111/1365-2656.12256).

Real adults vary in size. Yellowstone's reference ranges are 26–36 inches at the shoulder, 100–130 pounds for males and 80–110 pounds for females. These are population-specific ranges, not universal limits or a rule that leaders must be the largest animal. [National Park Service, Wolf Ecology](https://www.nps.gov/yell/learn/nature/wolf.htm).

Alaska's wildlife agency describes coats from black through gray and tan to nearly white, with gray and black most common. It also notes regional differences in body size and coloration. [Alaska Department of Fish and Game, species profile](https://www.adfg.alaska.gov/index.cfm?adfg=wolf.main).

## Translating research into a game

Variation should be visible before it matters in combat: body size, build and coat help distinguish individuals. Stronger, heavier wolves may withstand and inflict more damage, while speed and individual boldness create other tradeoffs. The exact multipliers and the most exaggerated heavy animals are fictional balance choices.

Coat selection is independent of combat rolls in this design. Color is visual variety, not a reliable difficulty code. Population-level associations between coloration and behavior do not justify treating every individual of one color as the same temperament.

A leader's death should produce a temporary loss of confidence or coordination among wolves that perceive it. Different survivors can hesitate, retreat or remain committed, then recover at different times. This is a readable, time-compressed interpretation of social disruption, not a measured seconds-long sequence from the cited studies. It must preserve individual perception: a distant wolf should not instantly learn the player's hidden position.

## Individual profiles in this build

Each adult receives one seeded profile when spawned. Its birth traits remain fixed for that individual's lifetime; injuries change its current condition separately. A new run creates new individuals. Supplying the same seed reproduces a profile for tests.

| Trait | Implementation |
| --- | --- |
| Ordinary adult size | Scale 0.80–1.13, with overlapping male and female distributions. |
| Exceptional size | A 4% chance of scale 1.145–1.20. A large adult can be about 50% taller than the smallest permitted adult; this range exists for encounter readability. |
| Simulated mass | 30–65 kg, used as a game balance input rather than a physics or veterinary estimate. |
| Coats | Silver-gray, charcoal, brown-gray, tawny, pale-gray and dark-sable, plus individual tone and patch variation. |
| Physical ability | Size and condition influence health, bite strength, walking and rushing speed, turning and time between attacks. Bulk helps damage and resilience with a modest agility cost; individual ranges overlap. |
| Temperament and senses | Independent boldness, experience, sight and hearing rolls distinguish individuals beyond their appearance. |
| Progression | Higher levels retain the existing capped health and speed growth; individual size, color and temperament are not rerolled by progression. |
| Leadership | A social role. Giving the same profile leadership does not add health, size, damage or speed. |

Visuals, hit areas and detached limbs follow individual size. Coats use separate material parameters, so changing one animal's appearance does not recolor the pack. Fallen limbs retain the source coat and scale, including their settling height and blood-pool footprint.

An individual's bite strength also scales the initial and repeated damage during a mauling. Attack intervals vary, and large animals are generally harder to escape. Positional calls and mauling vocals use the profile's pitch. These values are gameplay parameters, not estimates of real bite force or sound frequency.

## Leader loss in this build

Each active pack initially has one leader. Its coat and physical stats are sampled normally. A direct crosshair sight ray identifies a visible wolf's coat, size class and alpha status within 40 metres; walls block identification. Defeating a leader pays the usual 25 credits.

While present and alert, the leader gets a brief opportunity to initiate an approach. Nearby packmates choose flanking directions relative to it, and its warning carries slightly farther. These are bounded coordination cues; leadership does not add physical stats or bypass normal perception checks.

The death is perceived locally: a nearby yelp can be heard, while more distant witnesses need a view of the event. Each wolf's senses modify these ranges. An uninformed wolf receives neither the player's hidden location nor an instant awareness increase.

Witnesses respond according to their own boldness. Cautious animals retreat and spend roughly 2.5–4.5 seconds recovering; a bolder animal may hold its ground with a shorter pause. An ongoing mauling continues. Calls can accompany the disruption. Survivors are still dangerous and remain part of the wave.

Coordination is reduced for roughly 5.5–7 seconds, allowing only one new rush at a time instead of two. When an informed survivor is available, experience and boldness determine who takes over. Replacement changes leadership, not physical stats. A 16-second protection window reduces repeated leader-loss reactions, preventing a series of leader kills from keeping the whole encounter permanently stunned.

These timers, the single-leader abstraction, replacement selection and the way strength affects player injury or struggle resistance are deliberate game mechanics. They do not simulate breeding seasons, kinship, reproduction or actual pack dissolution.

Research checked 19 September 2026. All wolf models, animations, coat treatment and behavior code remain the project's own implementation and existing credited assets; no source photography or recordings were imported for this change.
