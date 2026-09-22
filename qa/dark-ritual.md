# Dark sacrifice validation

- `test_dark_ritual.gd`: DARK_RITUAL failures=0 in headless and native rendered runs; native error log empty.
- Tests cover all ten animal/enemy types at 7.1%, 7% and zero HP, persistent collapse, no AI movement/bleeding while incapacitated, nearby/line-of-sight validation, exclusive victim claims, firing lock, interruption, successful sacrifice and no corpse reuse.
- Boon checks cover actual weapon damage, reload, spread, incoming damage, stacked maximum health, other movement/radar modifiers and expiry.
- Sacrificing a first-wave objective completes the mission and grants normal rewards; its boon survives the deferred transition to rest.
- Split-screen integration passes: controller starts a host-authoritative ritual, incapacitation and death replicate, only the performer receives the boon, and resistance is applied exactly once on both peers.
- Native screenshot inspected: fallen animal, rotating red pentagram, rising sparks, red lighting/overlay and readable progress.
- Test fixtures use elevated isolated actors for clear screenshots; island geometry is unchanged.
