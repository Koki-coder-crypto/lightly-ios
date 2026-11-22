#!/usr/bin/env python3
"""YouTube動画1「実は日本発祥の世界的発明5選」を一から生成するスクリプト。

外部の画像・音声・AIサービスは使わず、次だけで作ります。
- ナレーション: Open JTalk（オフライン音声合成）
- 映像: Pillow で1フレームずつ描画
- BGM: numpy で合成したオリジナル曲
- 書き出し: ffmpeg

使い方:  python3 make_video.py
必要なもの: ffmpeg, open_jtalk(+naist-jdic, nitech voice), numpy, Pillow, qrcode
"""
import math
import os
import subprocess
import tempfile
import wave

import numpy as np
import qrcode
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "書き出し")
W, H, FPS = 1080, 1920, 30
SR = 48000
FONT = "/usr/share/fonts/truetype/ipafont-gothic/ipag.ttf"
DIC = "/var/lib/mecab/dic/open-jtalk/naist-jdic"
VOICE = "/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice"

# ---------------------------------------------------------------- 台本
# (見出し, 大きい番号, テロップ, ナレーション, アイコン, 背景色2色)
SCENES = [
    dict(kind="hook", title="実は日本生まれ", sub="世界的発明 5選",
         say="あなたが毎日使っているあれ、実は全部、日本生まれなんです。",
         icon="japan", bg=((20, 20, 40), (120, 20, 40))),
    dict(kind="item", num=5, title="新幹線",
         sub="1964年 世界初の高速鉄道",
         say="第5位、新幹線。1964年、東京オリンピックの直前に開業した、世界初の高速鉄道です。",
         icon="train", bg=((10, 40, 80), (30, 120, 170))),
    dict(kind="item", num=4, title="カラオケ",
         sub="1970年代 神戸で誕生",
         say="第4位、カラオケ。1970年代に、神戸のバンドマン、井上大佑さんが生み出しました。",
         icon="mic", bg=((60, 10, 80), (200, 40, 130))),
    dict(kind="item", num=3, title="インスタントラーメン",
         sub="1958年 チキンラーメン",
         say="第3位、インスタントラーメン。1958年、安藤百福さんが、チキンラーメンとして発明しました。",
         icon="ramen", bg=((90, 30, 0), (230, 130, 20))),
    dict(kind="item", num=2, title="絵文字",
         sub="1999年 最初は176個",
         say="第2位、絵文字。1999年、携帯電話向けに作られた、たった176個から始まりました。",
         icon="emoji", bg=((90, 70, 0), (240, 190, 30))),
    dict(kind="item", num=1, title="QRコード",
         sub="1994年 デンソーウェーブ",
         say="そして第1位、QRコード。1994年に、日本のデンソーウェーブが開発しました。",
         icon="qr", bg=((0, 50, 40), (20, 160, 110))),
    dict(kind="outro", title="いくつ知ってた？",
         sub="コメントで教えてね",
         say="いくつ知っていましたか？コメントで教えてください。フォローもお願いします。",
         icon="comment", bg=((20, 20, 40), (60, 40, 120))),
]
GAP = 0.35  # シーン間の無音（秒）


def font(size):
    return ImageFont.truetype(FONT, size)


# ---------------------------------------------------------------- 音声
def tts(text, path):
    subprocess.run(["open_jtalk", "-x", DIC, "-m", VOICE, "-r", "1.12",
                    "-fm", "1.5", "-ow", path], input=text.encode("utf-8"),
                   check=True)
    with wave.open(path) as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    data = data.astype(np.float32) / 32768.0
    # 48kHz へリサンプル
    n = int(len(data) * SR / sr)
    return np.interp(np.linspace(0, len(data) - 1, n), np.arange(len(data)), data)


def bgm(total):
    """オリジナルの軽いループ曲（4コード + キック + ハット）。"""
    t = np.arange(int(total * SR)) / SR
    bpm = 100
    beat = 60 / bpm
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]  # Am F C G
    out = np.zeros_like(t)
    bar = beat * 4
    for i, start in enumerate(np.arange(0, total, bar)):
        seg = (t >= start) & (t < start + bar)
        tt = t[seg] - start
        env = np.minimum(1, tt / 0.3) * np.exp(-tt / 3.0)
        for m in chords[i % 4]:
            f = 440 * 2 ** ((m - 69) / 12)
            out[seg] += 0.05 * env * (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt))
        # アルペジオ
        for k in range(8):
            s0 = k * beat / 2
            m = chords[i % 4][k % 3] + 12
            f = 440 * 2 ** ((m - 69) / 12)
            ss = seg & (t >= start + s0) & (t < start + s0 + 0.4)
            ta = t[ss] - start - s0
            out[ss] += 0.035 * np.exp(-ta / 0.12) * np.sin(2 * np.pi * f * ta)
    # リズム
    for start in np.arange(0, total, beat):
        ss = (t >= start) & (t < start + 0.25)
        tk = t[ss] - start
        out[ss] += 0.18 * np.exp(-tk / 0.06) * np.sin(2 * np.pi * (50 + 80 * np.exp(-tk / 0.03)) * tk)
        hs = (t >= start + beat / 2) & (t < start + beat / 2 + 0.05)
        out[hs] += 0.02 * np.random.default_rng(1).standard_normal(hs.sum()) * np.exp(-(t[hs] - start - beat / 2) / 0.01)
    fade = np.minimum(1, np.minimum(t / 1.0, (total - t) / 1.5))
    return out * fade


# ---------------------------------------------------------------- 描画パーツ
def gradient(c1, c2, phase):
    y = np.linspace(0, 1, H)[:, None]
    x = np.linspace(0, 1, W)[None, :]
    k = np.clip(y * 0.8 + x * 0.2 + 0.08 * np.sin(phase + y * 3), 0, 1)[..., None]
    arr = np.array(c1)[None, None] * (1 - k) + np.array(c2)[None, None] * k
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def ease_out(x):
    x = max(0.0, min(1.0, x))
    return 1 - (1 - x) ** 3


def text_center(d, y, s, size, fill=(255, 255, 255), stroke=10, sc=(0, 0, 0)):
    f = font(size)
    # 幅に収まるよう縮小
    while d.textlength(s, font=f) > W - 100 and size > 40:
        size -= 6
        f = font(size)
    d.text((W // 2, y), s, font=f, fill=fill, anchor="mm",
           stroke_width=stroke, stroke_fill=sc)


_QR = None


def qr_img():
    global _QR
    if _QR is None:
        q = qrcode.QRCode(border=1, box_size=20)
        q.add_data("実は日本発祥")
        q.make()
        _QR = q.make_image(fill_color="black", back_color="white").convert("RGB")
    return _QR


def draw_icon(img, kind, cx, cy, s, t):
    d = ImageDraw.Draw(img)
    wob = math.sin(t * 3) * 0.04
    s = s * (1 + wob)
    if kind == "train":
        x0 = cx - s
        d.rounded_rectangle([x0, cy - s * .35, cx + s * .2, cy + s * .35], 30, fill="white")
        d.polygon([(cx + s * .2, cy - s * .35), (cx + s, cy + s * .2), (cx + s, cy + s * .35),
                   (cx + s * .2, cy + s * .35)], fill="white")
        d.rectangle([x0, cy + s * .08, cx + s, cy + s * .16], fill=(30, 90, 200))
        for i in range(4):
            wx = x0 + 40 + i * s * .28
            d.rounded_rectangle([wx, cy - s * .22, wx + s * .18, cy - s * .04], 10, fill=(40, 60, 90))
        d.polygon([(cx + s * .3, cy - s * .25), (cx + s * .7, cy + s * .05), (cx + s * .3, cy + s * .05)],
                  fill=(40, 60, 90))
        off = (t * 900) % 200
        for i in range(-1, 12):
            lx = cx - s * 1.2 + i * 200 - off
            d.line([lx, cy + s * .55, lx + 120, cy + s * .55], fill=(255, 255, 255, 160), width=12)
    elif kind == "mic":
        d.rounded_rectangle([cx - s * .3, cy - s, cx + s * .3, cy - s * .1], int(s * .3), fill=(230, 230, 240))
        for i in range(5):
            yy = cy - s * .85 + i * s * .15
            d.line([cx - s * .25, yy, cx + s * .25, yy], fill=(150, 150, 170), width=6)
        d.arc([cx - s * .5, cy - s * .7, cx + s * .5, cy + s * .1], 0, 180, fill="white", width=18)
        d.line([cx, cy + s * .1, cx, cy + s * .6], fill="white", width=18)
        d.line([cx - s * .3, cy + s * .6, cx + s * .3, cy + s * .6], fill="white", width=18)
        for i, a in enumerate((0, 1, 2)):
            r = s * (.75 + .18 * ((t * 1.5 + i / 3) % 1))
            d.arc([cx - r, cy - r - s * .4, cx + r, cy + r - s * .4], -40, 40, fill="white", width=8)
            d.arc([cx - r, cy - r - s * .4, cx + r, cy + r - s * .4], 140, 220, fill="white", width=8)
    elif kind == "ramen":
        for i in range(3):
            sx = cx - s * .4 + i * s * .4
            pts = [(sx + 25 * math.sin(t * 4 + k / 3 + i), cy - s * .4 - k * 9) for k in range(22)]
            d.line(pts, fill=(255, 255, 255), width=10)
        d.chord([cx - s, cy - s * .5, cx + s, cy + s * .9], 0, 180, fill=(200, 40, 30))
        d.rectangle([cx - s, cy + s * .18, cx + s, cy + s * .22], fill=(255, 220, 120))
        for i in range(-3, 4):
            d.arc([cx + i * s * .25 - s * .1, cy + s * .05, cx + i * s * .25 + s * .1, cy + s * .3],
                  180, 360, fill=(255, 220, 120), width=8)
        d.line([cx + s * .2, cy - s * .9, cx + s * .7, cy + s * .1], fill=(120, 70, 30), width=16)
        d.line([cx + s * .4, cy - s * .95, cx + s * .85, cy + s * .05], fill=(120, 70, 30), width=16)
    elif kind == "emoji":
        d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=(255, 210, 40), outline=(160, 110, 0), width=10)
        blink = 0.15 if (t % 2.2) < 0.15 else 1
        for ex in (-.35, .35):
            d.ellipse([cx + ex * s - s * .12, cy - s * .35 - s * .18 * blink,
                       cx + ex * s + s * .12, cy - s * .35 + s * .18 * blink], fill=(60, 30, 0))
        d.arc([cx - s * .6, cy - s * .4, cx + s * .6, cy + s * .6], 20, 160, fill=(60, 30, 0), width=22)
    elif kind == "qr":
        q = qr_img().resize((int(s * 1.8), int(s * 1.8)), Image.NEAREST)
        img.paste(q, (int(cx - s * .9), int(cy - s * .9)))
        sy = cy - s * .9 + (math.sin(t * 2.5) * .5 + .5) * s * 1.8
        d.rectangle([cx - s, sy - 6, cx + s, sy + 6], fill=(255, 40, 60))
    elif kind == "japan":
        d.rectangle([cx - s * 1.1, cy - s * .75, cx + s * 1.1, cy + s * .75], fill="white")
        r = s * .45 * (1 + 0.05 * math.sin(t * 4))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(200, 16, 46))
        f = font(int(s * .9))
        d.text((cx + s * 1.0, cy - s * .95), "?", font=f, fill=(255, 230, 0), anchor="mm",
               stroke_width=8, stroke_fill="black")
    elif kind == "comment":
        d.rounded_rectangle([cx - s, cy - s * .7, cx + s, cy + s * .5], 60, fill="white")
        d.polygon([(cx - s * .4, cy + s * .45), (cx - s * .6, cy + s * .9), (cx - s * .05, cy + s * .45)], fill="white")
        n = int(t * 3) % 4
        for i in range(3):
            c = (60, 40, 120) if i < n else (200, 200, 220)
            d.ellipse([cx - s * .55 + i * s * .55 - 35, cy - s * .1 - 35,
                       cx - s * .55 + i * s * .55 + 35, cy - s * .1 + 35], fill=c)


def caption_at(sc, t):
    import re
    parts = [p for p in re.split(r"(?<=[、。？！])", sc["say"]) if p]
    chunks, cur = [], ""
    for p in parts:
        if len(cur) + len(p) > 16 and cur:
            chunks.append(cur)
            cur = p
        else:
            cur += p
    chunks.append(cur)
    total = sum(len(c) for c in chunks)
    acc = 0.0
    for c in chunks:
        acc += len(c) / total * sc.get("vdur", 1)
        if t < acc:
            return c.rstrip("、。")
    return chunks[-1].rstrip("、。") if t < sc.get("vdur", 1) + 0.3 else ""


def draw_frame(sc, t, dur, gt, total):
    img = gradient(*sc["bg"], gt * 0.6)
    d = ImageDraw.Draw(img, "RGBA")
    # 背景の浮遊する丸
    for i in range(10):
        x = (i * 173 + gt * (20 + i * 4)) % (W + 200) - 100
        y = (i * 311 + math.sin(gt + i) * 60) % H
        r = 40 + (i * 37) % 90
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 18))

    pop = ease_out(t / 0.35)
    if sc["kind"] == "item":
        # 番号バッジ
        r = int(150 * pop)
        cx, cy = W // 2, 430
        if r > 0:
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 230, 0), outline="black", width=10)
            d.text((cx, cy + 5), f"{sc['num']}", font=font(max(10, int(190 * pop))),
                   fill="black", anchor="mm")
        text_center(d, 640, f"第{sc['num']}位", 70, fill=(255, 255, 255), stroke=6)
        icon_y = 1050
        title_y = 1450
    else:
        icon_y = 900
        title_y = 1350
    # アイコン
    ik = ease_out((t - 0.15) / 0.4)
    if ik > 0:
        draw_icon(img, sc["icon"], W // 2, icon_y, 260 * ik, gt)
        d = ImageDraw.Draw(img, "RGBA")
    # 見出し（スライドイン）
    k = ease_out((t - 0.3) / 0.35)
    if k > 0:
        y = title_y + (1 - k) * 120
        text_center(d, y, sc["title"], 130, fill=(255, 240, 80), stroke=12)
    k2 = ease_out((t - 0.6) / 0.35)
    if k2 > 0:
        bw = int(900 * k2)
        d.rounded_rectangle([W // 2 - bw // 2, title_y + 110, W // 2 + bw // 2, title_y + 220],
                            30, fill=(0, 0, 0, 150))
        if k2 > 0.6:
            text_center(d, title_y + 165, sc["sub"], 64, stroke=4)
    if sc["kind"] == "hook":
        text_center(d, 330, "9割が知らない", 110, fill="white", stroke=12, sc=(200, 16, 46))
    # ナレーション字幕（句読点で区切り、文字数に比例して表示）
    cap = caption_at(sc, t - 0.15)
    if cap:
        f = font(62)
        tw = d.textlength(cap, font=f)
        while tw > W - 120:
            f = font(f.size - 4)
            tw = d.textlength(cap, font=f)
        d.rounded_rectangle([W // 2 - tw / 2 - 30, 1700, W // 2 + tw / 2 + 30, 1810], 20, fill=(0, 0, 0, 170))
        d.text((W // 2, 1755), cap, font=f, fill="white", anchor="mm")
    # 上部のシリーズ帯
    d.rectangle([0, 0, W, 150], fill=(0, 0, 0, 120))
    d.text((W // 2, 80), "日本発祥ランキング", font=font(56), fill="white", anchor="mm")
    # 進行バー
    d.rectangle([0, H - 26, int(W * gt / total), H], fill=(255, 230, 0))
    return img


# ---------------------------------------------------------------- 組み立て
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp = tempfile.mkdtemp()
    voices = []
    for i, sc in enumerate(SCENES):
        v = tts(sc["say"], os.path.join(tmp, f"v{i}.wav"))
        sc["vdur"] = len(v) / SR
        sc["dur"] = sc["vdur"] + GAP
        voices.append(v)
    total = sum(sc["dur"] for sc in SCENES) + 0.5

    # 音声ミックス
    n = int(total * SR)
    voice = np.zeros(n)
    pos = 0.15
    starts = []
    for sc, v in zip(SCENES, voices):
        starts.append(pos)
        i0 = int(pos * SR)
        voice[i0:i0 + len(v)] += v[: n - i0]
        pos += sc["dur"]
    music = bgm(total)
    # ナレーション中はBGMを下げる（ダッキング）
    env = np.convolve((np.abs(voice) > 0.01).astype(float), np.ones(SR // 5) / (SR // 5), "same")
    mix = voice * 1.1 + music * (1 - 0.55 * np.clip(env * 3, 0, 1))
    mix = mix / max(1e-6, np.abs(mix).max()) * 0.9
    wav_path = os.path.join(tmp, "mix.wav")
    with wave.open(wav_path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())

    out = os.path.join(OUT_DIR, "YouTube動画1_日本発祥ランキング.mp4")
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", wav_path,
         "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", out],
        stdin=subprocess.PIPE)
    frames = int(total * FPS)
    for f in range(frames):
        gt = f / FPS
        idx = max(i for i, s in enumerate(starts) if s - 0.15 <= gt) if gt >= 0 else 0
        sc = SCENES[idx]
        t = gt - (starts[idx] - 0.15)
        ff.stdin.write(draw_frame(sc, t, sc["dur"], gt, total).tobytes())
    ff.stdin.close()
    ff.wait()

    # サムネイル
    th = draw_frame(SCENES[0], 2.0, SCENES[0]["dur"], 1.0, total)
    th.save(os.path.join(OUT_DIR, "サムネイル.png"))
    print(out, f"{total:.1f}s")


if __name__ == "__main__":
    main()
