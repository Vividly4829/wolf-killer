# All-animal limb loss validation

Godot 4.6.2, isolated test saves. New `animal_limbs.gd` supplies individual limb collision, accumulated impact damage, health-scaled severing thresholds, skin-bone/mesh hiding, wounds, detached fragments, bleeding and speed penalties. Supports deer, mink, duck/goose legs and wings, bear legs and werewolf limbs. Ordinary wolves retain their existing severing implementation with the same new threshold formula.

`test_all_animal_limbs.gd` verifies increasing thresholds and percentages across 18–700 HP, actual lower-limb ray collision, subthreshold injury, accumulated severing, temporary survival, bleeding/slowing, visual hiding, disabled missing-limb collision, bird wing removal, lethal co-op snapshots and network serialization. Native model captures generated; the deer capture was inspected. Gameplay/combat polish and split-session regression suites pass with no script errors.

Detached procedural limbs preserve their source geometry. Imported skinned deer/mink use matching-size simplified detached fragments; the live skinned limb is collapsed at its root bone after animation updates. This does not add human dismemberment or change the original island assets.
