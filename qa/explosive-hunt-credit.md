# Explosive hunting objective credit

Removed the legacy ruined-meat exclusion from hunt objectives and stopped tagging blast victims as ineligible. Explosive kills count like firearm kills; old blast flags no longer disqualify a later kill. Predator kills remain uncredited and duplicate death notifications remain guarded.

Validation: `test_campaign.gd` passed 371 checks across all 30 waves. Regression coverage uses actual grenade, dynamite and grenade-launcher detonations to kill deer, checks exactly one objective increment, and verifies progression to the next wave. It also checks a deer carrying the legacy ruined-meat flag.
