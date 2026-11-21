#!/usr/bin/env python3
"""Tileable retro wallpaper patterns (original designs in a CDE-like mood).
   python3 make_patterns.py            -> tiles/*.png + comparison.png
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "tiles"); os.makedirs(OUT, exist_ok=True)

# muted slate blue, few levels (dark -> light)
RAMP = np.array([(84,98,128),(94,110,142),(104,121,155),(114,132,166),(126,143,176),(140,156,188)], np.uint8)
BASE = 2

def quant(v, levels=RAMP):
    """v: field in [0,1] -> palette levels"""
    idx = np.clip((v * len(levels)).astype(int), 0, len(levels)-1)
    return levels[idx]

def per_noise(n, cutoff, seed):
    """periodic (tileable) noise through an FFT low-pass, 0..1"""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((n, n)))
    k = np.fft.fftfreq(n)[:,None]**2 + np.fft.fftfreq(n)[None,:]**2
    v = np.real(np.fft.ifft2(f * np.exp(-k / (2*cutoff**2))))
    v = (v - v.min()) / (v.max() - v.min())
    return v

BAYER4 = np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]) / 16.0

def dither(v, n_levels, n):
    t = np.tile(BAYER4, (n//4, n//4))
    return np.clip(np.floor(v*(n_levels-1) + t), 0, n_levels-1).astype(int)

def solid(n, i=BASE):
    return np.tile(RAMP[i], (n, n, 1)).astype(np.uint8)

# 1 linen: fine weave, barely visible
def linen(n=64, seed=1):
    rng = np.random.default_rng(seed)
    rows = rng.random(n); cols = rng.random(n)
    v = 0.5 + 0.18*(np.sin(np.arange(n)*np.pi/1)[:,None]*0) \
        + 0.22*(rows[:,None]-0.5) + 0.22*(cols[None,:]-0.5)
    v += 0.10*(per_noise(n, 0.08, seed) - 0.5)
    idx = dither(np.clip(v,0,1)*0.6+0.2, 4, n) + 1
    return RAMP[idx]

# 2 paving: embossed stones in a bond, Motif bevel, slightly different tints
def paving(n=192, seed=5):
    rng = np.random.default_rng(seed)
    img = solid(n)
    hi, lo = RAMP[4], RAMP[0]
    h = n // 8; w = n // 4
    for r in range(8):
        off = (w//2) * (r % 2)
        y = r*h
        for c in range(4):
            x = c*w + off
            tone = RAMP[rng.choice([2, 2, 2, 3])]
            for yy in range(y, y+h):
                for xx in range(x, x+w):
                    img[yy % n, xx % n] = tone
            for xx in range(x, x+w):
                img[y % n, xx % n] = hi; img[(y+h-1) % n, xx % n] = lo
            for yy in range(y, y+h):
                img[yy % n, x % n] = hi; img[yy % n, (x+w-1) % n] = lo
    return img

# 3 waves: scale pattern of concentric arcs, subtle
def waves(n=96):
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    r = n / 2; dy_row = n / 4
    img = solid(n, 1)
    centers = []
    for row in range(-8, 9):
        for col in range(-2, 3):
            centers.append((row * dy_row, col * n + (r if row % 2 else 0)))
    for cy, cx in sorted(centers):     # top to bottom: lower arcs cover upper ones
        d = np.hypot(yy - cy, xx - cx)
        # periodic: distance across the tile border in x
        disc = d < r
        ring = np.floor(d / (r / 4)).astype(int)
        col_idx = np.where(ring % 2 == 0, 3, 2)
        img[disc] = RAMP[col_idx[disc]]
        img[disc & (d > r - 1.2)] = RAMP[0]
        img[disc & (d > r - 2.4) & (d <= r - 1.2)] = RAMP[4]
    return img

# 4 Granit: kachelbares Rauschen, Bayer-gerastert
def granite(n=128):
    v = 0.6*per_noise(n, 0.04, 3) + 0.4*per_noise(n, 0.18, 4)
    v = (v - v.min())/(v.max()-v.min())
    idx = dither(v*0.7+0.15, 4, n) + 1
    return RAMP[idx]

# 5 diamonds: small embossed checks
def diamonds(n=32):
    yy, xx = np.mgrid[0:n, 0:n]
    a = (xx + yy) % n; b = (xx - yy) % n
    img = solid(n)
    img[a == 0] = RAMP[4]; img[a == 1] = RAMP[4]
    img[b == 0] = RAMP[0]; img[b == n-1] = RAMP[1]
    return img

# 6 twill: diagonal weave stripes, very calm
def twill(n=32):
    yy, xx = np.mgrid[0:n, 0:n]
    d = (xx + 2*yy) % 8
    idx = np.choose(d, [3,3,2,2,2,1,2,2])
    return RAMP[idx]

PATTERNS = [("leinen","Linen",linen()),("pflaster","Paving",paving()),
            ("wellen","Waves",waves()),("granit","Granite",granite()),
            ("rauten","Diamonds",diamonds()),("koeper","Twill",twill())]

def tiled(tile, w, h):
    t = Image.fromarray(tile.astype(np.uint8))
    im = Image.new("RGB", (w, h))
    for y in range(0, h, t.height):
        for x in range(0, w, t.width):
            im.paste(t, (x, y))
    return im

if __name__ == "__main__":
    W, H = 420, 260
    sheet = Image.new("RGB", (3*W + 40, 2*H + 90), (230,230,230))
    d = ImageDraw.Draw(sheet)
    try: font = ImageFont.truetype("/usr/share/fonts/noto/NotoSans-Regular.ttf", 18)
    except OSError: font = ImageFont.load_default()
    for i, (key, name, tile) in enumerate(PATTERNS):
        Image.fromarray(tile.astype(np.uint8)).save(os.path.join(OUT, f"{key}.png"))
        x = 10 + (i % 3)*(W+10); y = 10 + (i//3)*(H+40)
        sheet.paste(tiled(tile, W, H), (x, y))
        d.text((x, y+H+6), f"{i+1}  {name}  ({tile.shape[1]}×{tile.shape[0]} px Kachel)", fill=(30,30,30), font=font)
    sheet.save(os.path.join(HERE, "comparison.png"))
    print(os.path.join(HERE, "comparison.png"))
