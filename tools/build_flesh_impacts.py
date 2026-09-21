"""Build original, non-tonal wet impact Foley; no third-party recordings."""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 44100

for variant in range(3):
    rng = random.Random(98130 + variant)
    low = body = 0.0
    values = []
    duration = 0.24 + variant * 0.018
    for i in range(int(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.07 * (noise - low)
        body += 0.018 * (noise - body)
        # Broadband slap, low body thump, then irregular short wet crackles.
        attack = 1 - math.exp(-2400 * t)
        slap = (noise - low) * math.exp(-100 * t) * 0.42
        thump = body * math.exp(-24 * t) * 3.3
        wet = low * math.exp(-32 * t) * 1.9
        for onset, decay in [(0.018, 125), (0.043, 90), (0.081, 75)]:
            local = t - onset * (1 + variant * 0.07)
            if local >= 0:
                wet += (noise - low) * (1 - math.exp(-1800 * local)) * math.exp(-decay * local) * 0.17
        tail = min(1, (duration - t) / 0.02)
        values.append(math.tanh((slap + thump + wet) * 2.0) * attack * tail)
    peak = max(abs(v) for v in values)
    pcm = b"".join(struct.pack("<h", round(v / peak * 0.88 * 32767)) for v in values)
    with wave.open(str(OUT / f"flesh_hit_{variant + 1}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)
