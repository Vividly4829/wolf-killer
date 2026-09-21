# Heavier gunshot audio — 2026-09-20

24 original mono, 48 kHz gunshot WAVs (three each for musket, shotgun, rifle, pistol, revolver, pepperbox, blunderbuss and heavy rifle), generated with `tools/build_gunshots.py`. Source files total 3.87 MB. Each combines broadband crack, bass/midrange turbulence, pressure impulse and filtered outdoor reflections. No third-party sound recording was used.

Local firearms play at -6 dB, with narrow pitch variation. Individual WAV peaks are -1.50 dBFS; no source samples clip. A single shared master hard limiter caps mixed peaks at -1 dB. Gunshots have separate local/spatial voice pools so pellet hits, coins or barks cannot steal their tails. Host and client firearm reports replicate positionally to other hunters, excluding the shooter. Bow/throw sounds retain their original local release and gain.

Godot 4.6.2 headless checks passed:
- Main script compilation and all new audio imports.
- `tests/test_gunshot_audio.gd`: catalog sound coverage, variant changes, sample duration/rate, gun tails surviving dense impact/bark playback, quiet release routing, pause/resume and shared limiter.
- `tests/test_split_session.gd`: actual host/client firing and exactly one positional report per remote shooter, plus existing split-screen controller/pickup/store/reconnect checks.

Logs: `gunshot-audio.log`, `gunshot-coop.log`, `gunshot-import.log`. Source mastering values: `gunshot-levels.json`. Preview sequence: musket, revolver, shotgun, heavy rifle (`gunshot-preview.wav`), at the local gameplay gain. This is automated audio routing/mastering verification; perceived sound on the user's speakers remains a listening check.
