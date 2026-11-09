#!/usr/bin/env python3
"""Generates the app's two original beep tones as 16-bit mono WAV files.

    python3 -I scripts/make-beeps.py

beep-short.wav: countdown tick (880 Hz, 0.15 s)
beep-long.wav:  segment change (two-tone 660 → 990 Hz, 0.45 s)
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "RunWalk" / "Resources"


def tone(parts, volume=0.6, fade=0.012):
    samples = []
    for freq, seconds in parts:
        n = int(RATE * seconds)
        f = int(RATE * fade)
        for i in range(n):
            env = min(1.0, i / f, (n - i) / f)
            samples.append(volume * env * math.sin(2 * math.pi * freq * i / RATE))
    return samples


def write(name, samples):
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))


write("beep-short.wav", tone([(880, 0.15)]))
write("beep-long.wav", tone([(660, 0.2), (990, 0.25)]))
print("wrote", OUT / "beep-short.wav", OUT / "beep-long.wav")
