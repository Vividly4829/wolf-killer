# Weapon balance validation

- All 35 weapons use prices above 25 and at most 1,000, except the spear at exactly 25. The maximum is exactly 1,000.
- Five guide pages cover every weapon, sorted by price; displayed prices match store data and gun reloads match runtime values after the reload speed adjustment.
- Controller paging wraps; returning preserves selected starting level and credits.
- Grenade/dynamite fire paths retain ownership with zero loaded/reserve ammunition. Switching, reloading and store re-equipping cannot refill or duplicate them mid-round.
- Round rest restores one of each, as does the remote-player wake path. Free Play reload restores practice explosives.
- Headless integration test: WEAPON_BALANCE failures=0. Native rendered test also passed; inspected guide screenshots for layout and readability.

Pricing rationale: finite, difficult throws are cheapest; reusable quiet bows and crossbow charge for stealth and precision; sidearms scale with capacity, accuracy and reload downtime. Rifles charge for reach, stopping power and penetration. Dual weapons/repeaters carry a pack-control premium. Recurring explosives include area damage and free round replenishment in their purchase price. The self-recharging aether musket and high-capacity drum Luger sit at the top. The starter musket remains a free starting grant but replacement/additional copies have a purchase price.
