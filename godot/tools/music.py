#!/usr/bin/env python3
"""배경음악 · 효과음 생성기 (직접 작곡한 것이라 저작권 문제가 없다).
  python3.13 tools/music.py      →  godot/audio/*.wav  (16kHz · 16bit · mono)
numpy 가 필요하다.
"""
import os, struct, math, sys
import numpy as np

SR = 16000
NAMES = { 'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(name):
    n = NAMES[name[0]]; rest = name[1:]
    if rest[0] == '#': n += 1; rest = rest[1:]
    elif rest[0] == 'b': n -= 1; rest = rest[1:]
    return n + (int(rest) + 1) * 12


def hz(m): return 440.0 * 2 ** ((m - 69) / 12.0)


def env(n, a, d, s, r, hold):
    """hold 초 동안 누르고 r 초 동안 놓는다."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), np.where(t < a + d, 1 - (1 - s) * (t - a) / max(d, 1e-4), s))
    rel = np.clip(1 - (t - hold) / max(r, 1e-4), 0, 1)
    return e * np.where(t > hold, rel, 1.0)


def tone(kind, f, dur):
    r = { 'pad': 0.5, 'bell': 0.9, 'pluck': 0.25, 'koto': 0.5}.get(kind, 0.08)
    n = int((dur + r) * SR); t = np.arange(n) / SR; ph = 2 * np.pi * f * t
    if kind == 'accordion':
        v = np.zeros(n)
        for det in (0.996, 1.004):
            p = (f * det * t) % 1.0
            v += np.where(p < 0.3, 1.0, -0.45)
        v = v * 0.33 * (1 + 0.12 * np.sin(2 * np.pi * 5.5 * t)) * env(n, 0.03, 0.05, 0.85, r, dur)
    elif kind == 'pluck':
        v = (np.sin(ph) + 0.5 * np.sin(2 * ph) * np.exp(-t * 9) + 0.3 * np.sin(3 * ph) * np.exp(-t * 14)) * np.exp(-t * 4.5) * 0.6
        v *= env(n, 0.004, 0.01, 1, r, dur)
    elif kind == 'koto':
        v = (np.sin(ph) + 0.6 * np.sin(2 * ph) * np.exp(-t * 6) + 0.35 * np.sin(3 * ph) * np.exp(-t * 10) + 0.2 * np.sin(5 * ph) * np.exp(-t * 18))
        v *= np.exp(-t * 2.6) * 0.55 * env(n, 0.003, 0.01, 1, r, dur + 0.3)
    elif kind == 'bell':
        v = (np.sin(ph) + 0.4 * np.sin(2.76 * ph) * np.exp(-t * 5) + 0.25 * np.sin(4 * ph) * np.exp(-t * 7)) * np.exp(-t * 1.8) * 0.5
        v *= env(n, 0.005, 0.01, 1, r, dur + 0.5)
    elif kind == 'pad':
        v = (np.sin(ph) + np.sin(ph * 1.003) + 0.3 * np.sin(2 * ph)) * 0.22 * env(n, 0.35, 0.2, 0.8, r, dur)
    elif kind == 'bass':
        p = (f * t) % 1.0
        v = (2 * np.abs(2 * p - 1) - 1) * 0.7 * env(n, 0.008, 0.1, 0.7, r, dur) + np.sin(ph) * 0.25 * env(n, 0.008, 0.1, 0.7, r, dur)
    elif kind == 'square':
        p = (f * t) % 1.0
        v = np.where(p < 0.5, 1.0, -1.0) * 0.3 * env(n, 0.006, 0.06, 0.7, r, dur)
        v += np.where((f * 1.005 * t) % 1.0 < 0.25, 1.0, -0.33) * 0.14 * env(n, 0.006, 0.06, 0.7, r, dur)
    else:   # soft lead
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.clip(t * 4, 0, 1)
        p = (f * t * vib) % 1.0
        v = ((2 * np.abs(2 * p - 1) - 1) * 0.6 + np.sin(ph) * 0.4) * 0.6 * env(n, 0.02, 0.08, 0.8, r, dur)
    return v


def drum(kind):
    if kind == 'k':
        n = int(0.22 * SR); t = np.arange(n) / SR
        return np.sin(2 * np.pi * (48 * t + 60 * (1 - np.exp(-t * 28)) / 28 * 1.6)) * np.exp(-t * 16) * 0.9
    rng = np.random.default_rng(7)
    if kind == 's':
        n = int(0.16 * SR); t = np.arange(n) / SR
        return (rng.uniform(-1, 1, n) * 0.6 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 26) * 0.6
    if kind == 't':   # 높은 손북 소리
        n = int(0.09 * SR); t = np.arange(n) / SR
        return (np.sin(2 * np.pi * 420 * t) * 0.6 + rng.uniform(-1, 1, n) * 0.3) * np.exp(-t * 45) * 0.5
    n = int(0.05 * SR); t = np.arange(n) / SR   # 'h' 하이햇
    x = rng.uniform(-1, 1, n)
    return (x - np.concatenate(([0], x[:-1]))) * np.exp(-t * 90) * 0.28


class Song:
    def __init__(self, bpm, beats):
        self.spb = 60.0 / bpm; self.n = int(beats * self.spb * SR); self.beats = beats
        self.buf = np.zeros(self.n)

    def add(self, wave, beat, gain):
        start = int(beat * self.spb * SR) % self.n
        idx = (start + np.arange(len(wave))) % self.n      # 꼬리는 처음으로 감아 넣어 이음매를 없앤다
        np.add.at(self.buf, idx, wave * gain)

    def line(self, kind, text, gain, start=0.0, octave=0):
        beat = start
        for tok in text.split():
            if tok == '|': continue
            name, length = tok.split(':'); length = float(length)
            if name != '-': self.add(tone(kind, hz(midi(name) + octave * 12), length * self.spb * 0.92), beat, gain)
            beat += length
        return beat - start

    def chord(self, kind, names, beat, length, gain):
        for name in names: self.add(tone(kind, hz(midi(name)), length * self.spb), beat, gain)

    def drums(self, pattern, step, gain, bars_beats):
        """pattern: 한 마디의 글자열, step: 글자 하나의 박 길이"""
        beat = 0.0
        while beat < self.beats - 1e-6:
            for k, ch in enumerate(pattern):
                if ch != '.': self.add(drum(ch), beat + k * step, gain)
            beat += bars_beats

    def render(self, path, peak=0.72):
        v = self.buf / max(1e-6, np.max(np.abs(self.buf))) * peak
        save(path, v)


def save(path, v):
    data = (np.clip(v, -1, 1) * 32767).astype('<i2').tobytes()
    with open(path, 'wb') as f:
        f.write(b'RIFF' + struct.pack('<I', 36 + len(data)) + b'WAVEfmt ' + struct.pack('<IHHIIHH', 16, 1, 1, SR, SR * 2, 2, 16) + b'data' + struct.pack('<I', len(data)) + data)


CH = { 'C': ['C3', 'E3', 'G3'], 'Am': ['A2', 'C3', 'E3'], 'F': ['F2', 'A2', 'C3'], 'G': ['G2', 'B2', 'D3'], 'Dm': ['D3', 'F3', 'A3'], 'G7': ['G2', 'B2', 'F3'],
       'Em': ['E3', 'G3', 'B3'], 'D': ['D3', 'F#3', 'A3'], 'A': ['A2', 'C#3', 'E3'], 'E': ['E3', 'G#3', 'B3'], 'Bb': ['Bb2', 'D3', 'F3'], 'Cmaj': ['C3', 'E3', 'G3'],
       'A7': ['A2', 'C#3', 'G3'], 'Dm7': ['D3', 'F3', 'C4'], 'Am7': ['A2', 'C3', 'G3'], 'C6': ['C3', 'E3', 'A3']}


def comp(s, chords, beats_per, kind_bass, kind_chord, style, gb=0.5, gc=0.22):
    for k, name in enumerate(chords):
        b = k * beats_per; notes = CH[name]
        if style == 'waltz':
            s.add(tone(kind_bass, hz(midi(notes[0]) - 12), s.spb * 0.9), b, gb)
            for off in (1, 2): s.chord(kind_chord, [notes[1], notes[2]], b + off, 0.5, gc)
        elif style == 'pad':
            s.chord('pad', notes, b, beats_per, gc); s.add(tone(kind_bass, hz(midi(notes[0]) - 12), s.spb * beats_per * 0.9), b, gb)
        elif style == 'drive':
            for e in range(int(beats_per * 2)): s.add(tone(kind_bass, hz(midi(notes[0]) - 12 + (12 if e % 4 == 3 else 0)), s.spb * 0.42), b + e * 0.5, gb)
            s.chord('pad', notes, b, beats_per, gc)
        elif style == 'walk':
            walk = [notes[0], notes[1], notes[2], notes[1]]
            for e in range(4): s.add(tone(kind_bass, hz(midi(walk[e]) - 12), s.spb * 0.8), b + e, gb)
            for off in (1.67, 3.67): s.chord(kind_chord, notes, b + off, 0.3, gc)
        else:   # 'arp'
            s.add(tone(kind_bass, hz(midi(notes[0]) - 12), s.spb * 1.8), b, gb)
            if beats_per >= 4: s.add(tone(kind_bass, hz(midi(notes[2]) - 12), s.spb * 1.8), b + 2, gb * 0.8)
            for e in range(int(beats_per * 2)): s.add(tone(kind_chord, hz(midi(notes[e % 3]) + 12), s.spb * 0.4), b + e * 0.5, gc)


def paris():
    s = Song(132, 48)
    comp(s, ['C', 'Am', 'F', 'G', 'C', 'Am', 'Dm', 'G7'] * 2, 3, 'bass', 'pluck', 'waltz')
    a = 'E5:2 G5:1 | E5:2 C5:1 | A4:1 C5:1 F5:1 | D5:3 | E5:2 G5:1 | C6:2 A5:1 | F5:1 E5:1 D5:1 | D5:2 B4:1'
    b = 'C5:1 E5:1 G5:1 | A5:2 E5:1 | F5:2 A5:1 | G5:3 | E5:1 G5:1 C6:1 | A5:2 C6:1 | D5:1 F5:1 A5:1 | G5:1 B4:1 D5:1'
    s.line('accordion', a, 0.5); s.line('accordion', b, 0.5, 24)
    return s


def kyoto():
    s = Song(76, 32)
    for bar in range(8):
        s.chord('pad', ['D3', 'A3'], bar * 4, 4, 0.2)
        s.add(tone('koto', hz(midi('D3')), 1.0), bar * 4, 0.45); s.add(tone('koto', hz(midi('A3')), 1.0), bar * 4 + 2, 0.35)
    s.line('koto', 'D5:1 Eb5:0.5 D5:0.5 A4:2 | Bb4:1 A4:1 G4:2 | A4:0.5 Bb4:0.5 D5:1 Eb5:1 D5:1 | A4:3 -:1 | G5:1 Eb5:1 D5:2 | Bb4:0.5 A4:0.5 G4:1 A4:2 | D5:0.5 Eb5:0.5 G5:1 Eb5:1 D5:1 | D5:3 -:1', 0.6)
    return s


def cairo():
    s = Song(96, 32)
    for bar in range(8):
        s.add(tone('bass', hz(midi('D2')), 0.9), bar * 4, 0.5); s.add(tone('bass', hz(midi('A2')), 0.7), bar * 4 + 2, 0.4)
        s.chord('pad', ['D3', 'A3'], bar * 4, 4, 0.12)
    s.drums('k.t..tk..t..t...', 0.25, 0.5, 4)
    s.line('pluck', 'D5:1 Eb5:0.5 F#5:0.5 G5:1 F#5:1 | Eb5:0.5 F#5:0.5 Eb5:1 D5:2 | A5:1 G5:0.5 F#5:0.5 G5:1 A5:1 | Bb5:0.5 A5:0.5 G5:1 F#5:2 | D5:0.5 F#5:0.5 A5:1 G5:1 F#5:1 | Eb5:1 F#5:1 Eb5:1 D5:1 | C5:0.5 D5:0.5 Eb5:1 F#5:1 Eb5:1 | D5:4', 0.62)
    return s


def rome():
    s = Song(108, 32)
    comp(s, ['G', 'Em', 'C', 'D', 'G', 'Em', 'Am', 'D'], 4, 'bass', 'pluck', 'arp', 0.45, 0.16)
    s.line('pluck', 'B4:0.5 D5:0.5 G5:1 D5:1 B4:1 | B4:0.5 E5:0.5 G5:1 E5:2 | C5:0.5 E5:0.5 G5:1 E5:1 C5:1 | D5:1 F#5:1 A5:2 | G5:1 B5:1 A5:1 G5:1 | E5:1 G5:1 B5:2 | A5:0.5 G5:0.5 E5:1 C5:1 E5:1 | D5:1 F#5:1 D5:2', 0.62)
    return s


def newyork():
    s = Song(120, 32)
    comp(s, ['C6', 'Am7', 'Dm7', 'G7', 'C6', 'Am7', 'Dm7', 'G7'], 4, 'bass', 'pluck', 'walk', 0.5, 0.14)
    s.drums('h..hh..hh..hh..h', 0.3333, 0.3, 4)
    s.line('lead', 'E5:1 G5:0.67 A5:1.33 -:1 | C6:1 A5:0.67 G5:0.33 E5:2 | F5:1 A5:0.67 C6:1.33 A5:1 | B5:0.67 A5:0.33 G5:1 D5:2 | E5:0.67 G5:0.33 C6:1 A5:1 G5:1 | A5:1 C6:1 E6:2 | D6:0.67 C6:0.33 A5:1 F5:1 D5:1 | G5:1 F5:0.67 D5:0.33 B4:2', 0.5)
    return s


def iceland():
    s = Song(72, 32)
    comp(s, ['Am', 'F', 'C', 'G', 'Am', 'F', 'C', 'G'], 4, 'bass', 'pad', 'pad', 0.3, 0.3)
    s.line('bell', 'E5:2 A5:2 | C6:3 A5:1 | G5:2 E5:2 | D5:4 | E5:2 B5:2 | A5:2 F5:2 | E5:2 G5:2 | D5:2 B4:2', 0.5)
    return s


def santorini():
    s = Song(112, 32)
    comp(s, ['D', 'D', 'A', 'A', 'G', 'D', 'A', 'D'], 4, 'bass', 'pluck', 'arp', 0.45, 0.15)
    s.drums('k...t...k.t.t...', 0.25, 0.3, 4)
    s.line('pluck', 'F#5:0.5 A5:0.5 D6:1 A5:1 F#5:1 | F#5:0.5 G5:0.5 A5:1 F#5:2 | E5:0.5 A5:0.5 C#6:1 A5:1 E5:1 | E5:0.5 F#5:0.5 G5:1 E5:2 | G5:0.5 B5:0.5 D6:1 B5:1 G5:1 | F#5:1 A5:1 D6:2 | C#6:0.5 B5:0.5 A5:1 G5:1 E5:1 | D5:1 F#5:1 D5:2', 0.62)
    return s


def london():
    s = Song(92, 32)
    comp(s, ['F', 'C', 'Dm', 'Bb', 'F', 'C', 'Bb', 'F'], 4, 'bass', 'pad', 'pad', 0.4, 0.22)
    s.drums('k...h...s...h...', 0.25, 0.3, 4)
    s.line('bell', 'F5:1 A5:1 C6:2 | E5:1 G5:1 C6:2 | D5:1 F5:1 A5:2 | D5:1 F5:1 Bb5:2 | C6:1 A5:1 F5:2 | G5:1 E5:1 C5:2 | D5:1 F5:1 E5:1 G5:1 | F5:4', 0.55)
    return s


def sydney():
    s = Song(128, 32)
    comp(s, ['A', 'D', 'A', 'E', 'A', 'D', 'E', 'A'], 4, 'bass', 'pluck', 'arp', 0.5, 0.14)
    s.drums('k.h.s.h.k.k.s.h.', 0.25, 0.4, 4)
    a = 'E5:0.5 A5:0.5 C#6:1 A5:0.5 B5:0.5 A5:1'
    s.line('lead', a + ' | F#5:0.5 A5:0.5 D6:1 B5:1 A5:1 | C#6:1 B5:0.5 A5:0.5 E5:2 | G#5:0.5 B5:0.5 E6:1 B5:2 | ' + a + ' | D6:1 B5:1 A5:1 F#5:1 | E5:0.5 G#5:0.5 B5:1 G#5:1 E5:1 | A5:2 -:2', 0.5)
    return s


def seoul():
    s = Song(100, 48)
    for bar in range(16):
        s.add(tone('bass', hz(midi('A2')), 1.2), bar * 3, 0.4)
        if bar % 2 == 0: s.chord('pad', ['A3', 'E4'], bar * 3, 6, 0.16)
    s.drums('k..t.t', 0.5, 0.35, 3)
    a = 'A4:1 C5:0.5 D5:1.5 | E5:1.5 D5:0.5 C5:1 | D5:1 E5:0.5 G5:1.5 | E5:3 | G5:1 E5:0.5 D5:1.5 | C5:1 D5:0.5 E5:1.5 | D5:1 C5:0.5 A4:1.5 | A4:3'
    b = 'A5:1 G5:0.5 E5:1.5 | G5:1.5 E5:0.5 D5:1 | E5:1 D5:0.5 C5:1.5 | D5:3 | C5:1 D5:0.5 E5:1.5 | G5:1 E5:0.5 D5:1.5 | C5:1 A4:0.5 C5:1.5 | A4:3'
    s.line('koto', a, 0.6); s.line('koto', b, 0.6, 24)
    return s


def battle():
    s = Song(150, 32)
    comp(s, ['Am', 'F', 'G', 'Em', 'Am', 'F', 'G', 'E'], 4, 'bass', 'pad', 'drive', 0.5, 0.14)
    s.drums('k.h.s.h.k.h.s.hh', 0.25, 0.45, 4)
    s.line('square', 'A5:1 C6:1 E6:1 C6:1 | A5:1 C6:1 F6:1 C6:1 | B5:1 D6:1 G6:1 D6:1 | B5:1 E6:1 G5:1 B5:1 | E6:1.5 D6:0.5 C6:1 A5:1 | F6:1.5 E6:0.5 C6:1 A5:1 | G6:1.5 F6:0.5 D6:1 B5:1 | E6:2 G#5:2', 0.42)
    return s


def boss():
    s = Song(160, 32)
    comp(s, ['Dm', 'Bb', 'C', 'A', 'Dm', 'Bb', 'C', 'A'], 4, 'bass', 'pad', 'drive', 0.55, 0.14)
    s.drums('k.hks.h.k.hks.ss', 0.25, 0.5, 4)
    s.line('square', 'D5:0.5 F5:0.5 A5:1 D6:2 | D6:0.5 Bb5:0.5 F5:1 Bb5:2 | C6:0.5 G5:0.5 E5:1 G5:2 | C#6:1 A5:1 E5:2 | F6:1 E6:1 D6:1 A5:1 | F6:1 D6:1 Bb5:2 | E6:1 G6:1 E6:1 C6:1 | A5:1 C#6:1 E6:2', 0.42)
    return s


# ── 효과음 ───────────────────────────────────────────────
def notes_fx(seq, kind, gap, length, gain=0.6):
    total = int((gap * len(seq) + length + 0.4) * SR); v = np.zeros(total)
    for k, name in enumerate(seq):
        w = tone(kind, hz(midi(name)), length); st = int(k * gap * SR); v[st:st + len(w)] += w[:total - st] * gain
    return v


def fx():
    rng = np.random.default_rng(3)
    out = {}
    n = int(0.05 * SR); t = np.arange(n) / SR
    out['step'] = rng.uniform(-1, 1, n) * np.exp(-t * 70) * 0.16 + np.sin(2 * np.pi * 120 * t) * np.exp(-t * 60) * 0.2
    out['click'] = np.sin(2 * np.pi * 900 * t) * np.exp(-t * 60) * 0.3
    out['coin'] = notes_fx(['B5', 'E6'], 'bell', 0.07, 0.12, 0.5)
    out['chest'] = notes_fx(['C5', 'E5', 'G5', 'C6'], 'bell', 0.08, 0.2, 0.5)
    out['levelup'] = notes_fx(['C5', 'E5', 'G5', 'C6', 'E6'], 'square', 0.09, 0.22, 0.5)
    out['egg'] = notes_fx(['E6', 'G6', 'B6', 'E7'], 'bell', 0.06, 0.3, 0.4)
    out['win'] = notes_fx(['G5', 'G5', 'G5', 'C6', 'E6', 'G6'], 'square', 0.13, 0.3, 0.5)
    out['lose'] = notes_fx(['E5', 'D5', 'C5', 'A4'], 'lead', 0.2, 0.35, 0.5)
    out['good'] = notes_fx(['G5', 'C6'], 'bell', 0.08, 0.15, 0.5)
    out['bad'] = notes_fx(['E4', 'Eb4'], 'square', 0.1, 0.16, 0.4)
    out['job'] = notes_fx(['C5', 'G5', 'C6', 'E6', 'G6', 'C7'], 'bell', 0.1, 0.5, 0.45)
    n = int(0.3 * SR); t = np.arange(n) / SR
    out['crit'] = (rng.uniform(-1, 1, n) * np.exp(-t * 20) * 0.5 + np.sin(2 * np.pi * (90 * t - 80 * t * t)) * np.exp(-t * 12) * 0.7)
    n = int(0.5 * SR); t = np.arange(n) / SR
    out['boom'] = (rng.uniform(-1, 1, n) * np.exp(-t * 9) * 0.6 + np.sin(2 * np.pi * (70 * t - 40 * t * t)) * np.exp(-t * 7) * 0.8)
    n = int(0.9 * SR); t = np.arange(n) / SR
    growl = np.sin(2 * np.pi * (85 * t + 6 * np.sin(2 * np.pi * 9 * t))) + 0.5 * np.sin(2 * np.pi * (170 * t + 5 * np.sin(2 * np.pi * 11 * t)))
    out['roar'] = (growl * 0.5 + rng.uniform(-1, 1, n) * 0.2) * np.clip(t * 10, 0, 1) * np.exp(-t * 3)
    return out


SONGS = { 'city0': paris, 'city1': kyoto, 'city2': cairo, 'city3': rome, 'city4': newyork, 'city5': iceland, 'city6': santorini, 'city7': london, 'city8': sydney, 'city9': seoul, 'battle': battle, 'boss': boss}

if __name__ == '__main__' and '--race' not in sys.argv:
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
    os.makedirs(out_dir, exist_ok=True)
    size = 0
    for name, fn in SONGS.items():
        s = fn(); path = os.path.join(out_dir, name + '.wav'); s.render(path)
        size += os.path.getsize(path); print('%-8s %5.1f초' % (name, s.n / SR))
    for name, v in fx().items():
        path = os.path.join(out_dir, 'fx_' + name + '.wav')
        save(path, v / max(1e-6, np.max(np.abs(v))) * 0.8); size += os.path.getsize(path)
    print('합계 %.1f MB' % (size / 1e6))


# ══ 경마장 ══════════════════════════════════════════════════
def biquad_bp(x, f, q):
    """대역 통과 필터 (모음의 포먼트를 흉내 낸다)"""
    w0 = 2 * math.pi * f / SR; alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        v = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]; y2, y1 = y1, v; y[i] = v
    return y


def race_song():
    """경주 음악: 빠르고 쉼 없는 베이스, 떨리는 현, 계속 올라가는 선율"""
    s = Song(168, 32)
    roots = ['D2', 'D2', 'Bb1', 'Bb1', 'C2', 'C2', 'A1', 'A1']
    for bar, r in enumerate(roots):
        base = midi(r)
        for e in range(8):
            jump = [0, 12, 0, 7, 0, 12, 3, 7][e]
            s.add(tone('bass', hz(base + jump), s.spb * 0.4), bar * 4 + e * 0.5, 0.55)
    chords = [['D3', 'F3', 'A3'], ['D3', 'F3', 'A3'], ['Bb2', 'D3', 'F3'], ['Bb2', 'D3', 'F3'], ['C3', 'E3', 'G3'], ['C3', 'E3', 'G3'], ['A2', 'C#3', 'E3'], ['A2', 'C#3', 'E3']]
    for bar, ch in enumerate(chords):
        for name in ch:
            w = tone('pad', hz(midi(name) + 12), s.spb * 4)
            t = np.arange(len(w)) / SR
            s.add(w * (0.55 + 0.45 * np.sin(2 * np.pi * 13 * t)), bar * 4, 0.2)
    s.drums('k.hhs.hhk.hks.hs', 0.25, 0.5, 4)
    s.line('square', 'D5:0.5 F5:0.5 A5:0.5 D6:0.5 C6:0.5 A5:0.5 F5:0.5 A5:0.5 | Bb4:0.5 D5:0.5 F5:0.5 Bb5:0.5 A5:0.5 F5:0.5 D5:0.5 F5:0.5 | C5:0.5 E5:0.5 G5:0.5 C6:0.5 Bb5:0.5 G5:0.5 E5:0.5 G5:0.5 | A4:0.5 C#5:0.5 E5:0.5 A5:0.5 C#6:0.5 E6:0.5 A6:1', 0.34)
    s.line('square', 'D5:2 E5:2 | F5:2 G5:2 | G5:2 A5:2 | A5:2 C#6:2', 0.22, 0, 1)
    return s


def crowd_loop(seconds=8.0, rng=None):
    """관중석의 웅성임: 여러 목소리를 흉내 낸 띠 잡음이 출렁인다 (이음매 없이 반복)"""
    rng = rng or np.random.default_rng(11)
    n = int(seconds * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(14):
        voice = biquad_bp(rng.uniform(-1, 1, n), rng.uniform(400, 1400), 2.5)
        rate = rng.integers(1, 4) / seconds
        out += voice * (0.6 + 0.4 * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.28)))
    out += biquad_bp(rng.uniform(-1, 1, n), 2600, 1.2) * 0.4
    return out


def cheer(rng=None):
    """결승선 함성: 커졌다가 길게 잦아든다"""
    rng = rng or np.random.default_rng(12)
    n = int(2.6 * SR); t = np.arange(n) / SR
    roar = crowd_loop(2.6, rng) * 1.6
    for k in range(8):
        f = rng.uniform(500, 1100)
        voice = biquad_bp(np.sign(np.sin(2 * np.pi * (f * 0.25) * t * (1 + 0.04 * np.sin(2 * np.pi * 5 * t)))) * 0.5, f, 4)
        roar += voice * 0.6
    env = np.clip(t * 6, 0, 1) * np.exp(-np.maximum(0, t - 0.6) * 1.2)
    return roar * env


def shout(f0, vowel, rng=None):
    """동훈의 고함: 거친 톱니파 목소리 + 모음 포먼트 + 숨소리, 끝을 올렸다가 내린다"""
    rng = rng or np.random.default_rng(int(f0))
    n = int(0.85 * SR); t = np.arange(n) / SR
    glide = f0 * (1 + 0.35 * np.clip(t * 5, 0, 1) - 0.25 * np.clip((t - 0.45) * 3, 0, 1)) * (1 + 0.03 * np.sin(2 * np.pi * 7 * t))
    phase = np.cumsum(glide) / SR
    src = 2 * (phase % 1.0) - 1 + rng.uniform(-0.35, 0.35, n)
    f1, f2, f3 = vowel
    v = biquad_bp(src, f1, 5) * 1.0 + biquad_bp(src, f2, 6) * 0.7 + biquad_bp(src, f3, 8) * 0.35
    v = np.tanh(v * 6)
    env = np.clip(t * 30, 0, 1) * np.clip((0.85 - t) * 6, 0, 1)
    return v * env


def race_audio(out_dir):
    s = race_song(); s.render(os.path.join(out_dir, 'race.wav'))
    print('race    %5.1f초' % (s.n / SR))
    loop = crowd_loop()
    fade = int(0.5 * SR)
    loop[:fade] = loop[:fade] * np.linspace(0, 1, fade) + loop[-fade:] * np.linspace(1, 0, fade)
    loop = loop[:-fade]
    save(os.path.join(out_dir, 'fx_crowd.wav'), loop / np.max(np.abs(loop)) * 0.7)
    c = cheer(); save(os.path.join(out_dir, 'fx_cheer.wav'), c / np.max(np.abs(c)) * 0.8)
    for k, (f0, vowel) in enumerate([(210, (800, 1200, 2500)), (250, (700, 1100, 2400)), (190, (500, 900, 2400))]):
        v = shout(f0, vowel); save(os.path.join(out_dir, 'fx_shout%d.wav' % k), v / np.max(np.abs(v)) * 0.85)


if __name__ == '__main__' and '--race' in sys.argv:
    race_audio(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio'))
