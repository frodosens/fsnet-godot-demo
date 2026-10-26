#!/usr/bin/env python3
"""Original short synthesized prototype SFX; stdlib only, no borrowed samples."""
import math, pathlib, random, struct, wave
RATE = 22050
root = pathlib.Path(__file__).resolve().parents[1] / 'assets/audio'
root.mkdir(exist_ok=True)
for index, (name, length) in enumerate([('swing', .14), ('impact', .16), ('arrow', .13), ('magic', .23), ('critical', .24)]):
    rng = random.Random(4021 + index)
    frames = []
    previous = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE; phase = t / length
        noise = rng.uniform(-1, 1); high = (noise - previous) * .5; previous = noise
        env = min(1, t / .004) * (1-phase)**2
        if name == 'swing': value = high * math.sin(math.pi * phase)
        elif name == 'impact': value = .65 * math.sin(2*math.pi*(100*t-75*t*t)) + .35*noise*math.exp(-t*45)
        elif name == 'arrow': value = high * .8 + .2*math.sin(2*math.pi*1500*t)*math.exp(-t*30)
        elif name == 'magic': value = .65*math.sin(2*math.pi*(580*t+900*t*t)) + .25*math.sin(2*math.pi*880*t)
        else: value = .45*math.sin(2*math.pi*660*t) + .3*math.sin(2*math.pi*990*t) + .2*noise*math.exp(-t*40)
        frames.append(struct.pack('<h', round(max(-.22, min(.22, value*env*.20))*32767)))
    with wave.open(str(root / (name+'.wav')), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(RATE); output.writeframes(b''.join(frames))
