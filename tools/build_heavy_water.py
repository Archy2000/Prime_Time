"""Build dedicated heavy entries from water recordings, with a short cavity thump.

Run after extract_water_audio.py. No changes to ordinary splash/swimming assets.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/audio/water'
RATE = 44100

def read(name, speed=1.0):
    with wave.open(str(ASSETS / (name + '.wav')), 'rb') as w:
        a = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(float)
        a = a.reshape(-1, w.getnchannels()).mean(axis=1) / 32768
        step = speed * w.getframerate() / RATE
    return np.interp(np.arange(0, len(a) - 1, step), np.arange(len(a)), a)

def lowpass(a, cutoff):
    # Zero-pad to avoid circularly wrapping the impact into the tail.
    n = 1 << (len(a) * 2 - 1).bit_length()
    freq = np.fft.rfftfreq(n, 1 / RATE)
    return np.fft.irfft(np.fft.rfft(a, n) / (1 + (freq / cutoff) ** 4), n)[:len(a)]

def write(path, a):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype('<i2').tobytes())

rows = []
for variant in range(1, 4):
    rng = np.random.default_rng(4910 + variant)
    duration = 2.85 + variant * .08
    t = np.arange(int(RATE * duration)) / RATE
    mix = np.zeros(len(t))
    def layer(a, gain, delay=0):
        start = int(delay * RATE)
        length = min(len(a), len(mix) - start)
        mix[start:start + length] += a[:length] * gain

    # Displaced water mass: slowed real water, not a dry explosion or hard knock.
    splash = read(f'WaterSplashMedium_{variant:02d}', .70)
    splash -= np.mean(splash)
    layer(lowpass(splash, 2100), 1.0)
    layer(read(f'WaterSplashMedium_{variant % 4 + 1:02d}', 1.05), .27, .045)
    # Short descending, damped cavity pulse, with a noisy water-pressure attack.
    frequency = 52 + 108 * np.exp(-t * 18)
    phase = np.cumsum(frequency) * (2 * np.pi / RATE)
    envelope = (1 - np.exp(-t * 190)) * np.exp(-t * 9)
    cavity = np.sin(phase) * envelope
    noise = lowpass(rng.normal(0, 1, len(t)), 430)
    noise /= max(np.std(noise), .001)
    layer(cavity, .42)
    layer(noise * envelope, .13)
    # Water folding back into the cavity; onset follows the initial broad splash.
    churn = read('WaterAgitated_01', .82)
    offset = int((3 + variant * 5) * RATE)
    churn = lowpass(churn[offset:offset + len(t)], 1250)
    churn /= max(np.sqrt(np.mean(churn ** 2)), .001)
    u = np.arange(len(churn)) / RATE
    churn *= (1 - np.exp(-u * 8)) * np.exp(-u * 2.4)
    layer(churn, .13, .14)
    layer(lowpass(read(f'Bubble_{variant:02d}', .68), 1100), .28, .27)
    # Smooth tail, remove DC and leave mix headroom.
    mix -= lowpass(mix, 28)
    mix *= np.minimum(1, t / .004) * np.minimum(1, (duration - t) / .3)
    mix *= .88 / max(np.max(np.abs(mix)), .001)
    name = f'WaterHeavyEntry_{variant:02d}'
    write(ASSETS / (name + '.wav'), mix)
    rows.append({'name': name, 'seconds': duration, 'peak': float(np.max(np.abs(mix))),
                 'rms': float(np.sqrt(np.mean(mix ** 2))),
                 'sha256': hashlib.sha256((ASSETS / (name + '.wav')).read_bytes()).hexdigest(),
                 'method': 'layered source water + synthesized damped cavity pulse'})

(ROOT / 'research/heavy_water_assets.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
print(json.dumps(rows, indent=2))
