#!/usr/bin/env python3
"""Synthesize Reverie's original commerce cue without recorded audio samples.

Requires Python 3 and ffmpeg. The CAF output is mono 44.1 kHz, 16-bit linear PCM.
This cash-register-inspired cue is original; it is not Shopify's Cha-Ching clip.
"""

from __future__ import annotations

import argparse
import array
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import wave


RATE = 44_100
DURATION = 1.65


def synthesize() -> array.array:
    rng = random.Random(20261013)
    samples = [0.0] * round(RATE * DURATION)

    def add(start: float, duration: float, generator) -> None:
        offset = round(start * RATE)
        count = min(round(duration * RATE), len(samples) - offset)
        for index in range(count):
            samples[offset + index] += generator(index / RATE, index)

    # A light lever click followed by four short drawer-ratchet transients.
    for onset, strength in [(0.0, 0.18), (0.065, 0.12), (0.106, 0.16), (0.142, 0.12), (0.173, 0.10)]:
        previous_noise = [0.0]

        def click(t: float, _: int, volume=strength, state=previous_noise) -> float:
            noise = rng.uniform(-1.0, 1.0)
            filtered = noise - 0.78 * state[0]
            state[0] = noise
            attack = min(1.0, t / 0.0015)
            return volume * attack * math.exp(-t / 0.008) * (filtered + 0.4 * math.sin(2 * math.pi * 520 * t))

        add(onset, 0.05, click)

    # Two brief, inharmonic coin contacts, each synthesized from damped partials.
    for onset, base, volume in [(0.083, 1927, 0.16), (0.193, 2341, 0.13)]:
        def coin(t: float, _: int, frequency=base, strength=volume) -> float:
            attack = min(1.0, t / 0.002)
            return strength * attack * math.exp(-t / 0.082) * sum(
                weight * math.sin(2 * math.pi * frequency * ratio * t)
                for ratio, weight in [(1.0, 1.0), (1.43, 0.44), (2.31, 0.22)]
            )

        add(onset, 0.34, coin)

    # A bright struck bell is the main payoff, with a quieter second resonance.
    for onset, frequency, volume in [(0.235, 1217, 0.36), (0.273, 1649, 0.11)]:
        def bell(t: float, _: int, base=frequency, strength=volume) -> float:
            attack = min(1.0, t / 0.004)
            return strength * attack * sum(
                weight * math.exp(-t / decay) * math.sin(2 * math.pi * base * ratio * t)
                for ratio, weight, decay in [
                    (1.0, 1.0, 0.33),
                    (2.006, 0.45, 0.20),
                    (2.714, 0.21, 0.14),
                    (4.031, 0.10, 0.095),
                ]
            )

        add(onset, 1.31, bell)

    # Gentle reflection adds space without stereo channels or a recorded room.
    direct = samples.copy()
    for delay, level in [(0.034, 0.16), (0.058, 0.07)]:
        offset = round(delay * RATE)
        for index in range(offset, len(samples)):
            samples[index] += direct[index - offset] * level

    # Remove DC, normalize with headroom, and smoothly fade the final 90 ms.
    dc = sum(samples) / len(samples)
    samples = [sample - dc for sample in samples]
    scale = 0.74 / max(abs(sample) for sample in samples)
    pcm = array.array("h")
    for index, sample in enumerate(samples):
        remaining = (len(samples) - 1 - index) / RATE
        fade = 0.5 - 0.5 * math.cos(math.pi * min(1.0, remaining / 0.09))
        pcm.append(round(sample * scale * fade * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm


def write_wav(path: Path, pcm: array.array) -> None:
    with wave.open(str(path), "wb") as destination:
        destination.setnchannels(1)
        destination.setsampwidth(2)
        destination.setframerate(RATE)
        destination.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "Sources/Order.caf")
    parser.add_argument("--preview-wav", type=Path)
    arguments = parser.parse_args()
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    pcm = synthesize()
    with tempfile.TemporaryDirectory(prefix="reverie-order-sound-") as temporary:
        wav = Path(temporary) / "order.wav"
        write_wav(wav, pcm)
        subprocess.run(
            ["ffmpeg", "-v", "error", "-nostdin", "-y", "-i", str(wav), "-map_metadata", "-1", "-c:a", "pcm_s16le", "-fflags", "+bitexact", "-flags:a", "+bitexact", "-f", "caf", str(arguments.output)],
            check=True,
        )
    if arguments.preview_wav:
        arguments.preview_wav.parent.mkdir(parents=True, exist_ok=True)
        write_wav(arguments.preview_wav, pcm)
    print(f"Wrote {arguments.output}: {DURATION:.2f}s, mono, {RATE}Hz, 16-bit linear PCM; original synthesis.")


if __name__ == "__main__":
    main()
