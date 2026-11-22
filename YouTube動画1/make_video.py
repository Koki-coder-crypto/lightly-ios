#!/usr/bin/env python3
"""YouTube動画1（v2）を組み立てるスクリプト。

参考にした形式：顔出しなし雑学ショート（例：109万回再生の「日々のひと息雑学」）
  - 上部の黒帯に固定タイトル（白＋黄色の太字）
  - 中央の白い枠に、黒/赤の太字字幕 ＋ ゆるいクリップアート
  - 一文ごとにハードカットでイラストが切り替わる
  - 落ち着いた女性ナレーション ＋ 控えめなBGM

素材（素材/ フォルダ）：
  img0〜6.png … Higgsfield（gpt_image_2_6）で生成したイラスト
  voice.mp3   … Higgsfield（ElevenLabs v4, 声: Hana）で生成したナレーション
使い方：python3 make_video.py   （必要: ffmpeg, numpy, Pillow, IPAゴシック）
"""
import os, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "素材")
OUT = os.path.join(HERE, "書き出し")
TMP = os.path.join(OUT, "_tmp")
W, H = 1080, 1920
FONT = next(p for p in ["/usr/share/fonts/truetype/ipafont-gothic/ipag.ttf",
                        "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"] if os.path.exists(p))
RED, BLK = (220, 30, 30), (20, 20, 20)
TITLE = [("実は日本発祥の", (255, 255, 255)), ("世界的発明5選", (255, 214, 0))]
# (開始秒, イラスト番号, 字幕[(文字, 色)])  開始秒はナレーションの文字起こしから測定
SCENES = [
    (0.00, 0, [("毎日使っているあれも", BLK), ("実は日本生まれって知ってた？", RED)]),
    (3.98, 1, [("まずは「新幹線」", RED), ("1964年開業の世界初の高速鉄道", BLK)]),
    (11.22, 2, [("次は「カラオケ」", RED), ("1970年代に神戸のバンドマンが生み出した", BLK)]),
    (17.22, 3, [("「インスタントラーメン」は1958年", RED), ("チキンラーメンとして誕生", BLK)]),
    (22.58, 4, [("「絵文字」は1999年", RED), ("たった176個から始まった", BLK)]),
    (27.60, 5, [("そして「QRコード」", RED), ("1994年に日本のデンソーウェーブが開発", BLK)]),
    (34.02, 6, [("いくつ知ってた？", RED), ("コメントで教えてね", BLK)]),
]
END = 36.6


def fit(d, text, size, maxw):
    f = ImageFont.truetype(FONT, size)
    while d.textlength(text, font=f) > maxw:
        size -= 2
        f = ImageFont.truetype(FONT, size)
    return f


def frame(img_i, lines):
    im = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(im)
    for y, (t, c) in zip((250, 400), TITLE):
        d.text((W // 2, y), t, font=fit(d, t, 130, 1000), fill=c, anchor="mm", stroke_width=4, stroke_fill=c)
    d.rectangle([0, 520, W, 1580], fill=(255, 255, 255))
    y = 600
    for t, c in lines:
        d.text((W // 2, y), t, font=fit(d, t, 64, 1000), fill=c, anchor="mm", stroke_width=2, stroke_fill=c)
        y += 86
    pic = Image.open(os.path.join(SRC, f"img{img_i}.png")).convert("RGB").resize((800, 800), Image.LANCZOS)
    im.paste(pic, ((W - 800) // 2, 770))
    return im


def bgm(path, T, sr=48000):
    t = np.arange(int(T * sr)) / sr
    out = np.zeros_like(t)
    beat = 60 / 96
    ch = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
    for i, st in enumerate(np.arange(0, T, beat / 2)):
        m = ch[int(st // (beat * 4)) % 4][i % 3] + 12
        f = 440 * 2 ** ((m - 69) / 12)
        s = (t >= st) & (t < st + 0.5)
        tt = t[s] - st
        out[s] += 0.05 * np.exp(-tt / 0.18) * (np.sin(2 * np.pi * f * tt) + 0.2 * np.sin(4 * np.pi * f * tt))
    for i, st in enumerate(np.arange(0, T, beat * 4)):
        s = (t >= st) & (t < st + beat * 4)
        tt = t[s] - st
        for m in ch[i % 4]:
            f = 440 * 2 ** ((m - 69) / 12)
            out[s] += 0.018 * np.minimum(1, tt / 0.4) * np.sin(2 * np.pi * f * tt)
    out *= np.minimum(1, np.minimum(t / 0.5, (T - t) / 1.0))
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((out / np.abs(out).max() * 0.5 * 32767).astype(np.int16).tobytes())


def main():
    os.makedirs(TMP, exist_ok=True)
    with open(os.path.join(TMP, "list.txt"), "w") as fo:
        for i, (t, img, lines) in enumerate(SCENES):
            frame(img, lines).save(os.path.join(TMP, f"s{i}.png"))
            nxt = SCENES[i + 1][0] if i + 1 < len(SCENES) else END
            fo.write(f"file 's{i}.png'\nduration {nxt - t:.3f}\n")
        fo.write(f"file 's{len(SCENES) - 1}.png'\n")
    bgm(os.path.join(TMP, "bgm.wav"), END)
    out = os.path.join(OUT, "YouTube動画1_日本発祥の世界的発明5選.mp4")
    subprocess.run([
        "ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-i", os.path.join(TMP, "list.txt"),
        "-i", os.path.join(SRC, "voice.mp3"), "-i", os.path.join(TMP, "bgm.wav"),
        "-filter_complex",
        "[0:v]fps=30,format=yuv420p[v];[1:a]adelay=300|300[a1];[2:a]volume=0.18[a2];"
        "[a1][a2]amix=inputs=2:duration=longest:normalize=0,loudnorm=I=-14:TP=-1.5[a]",
        "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "18", "-preset", "medium",
        "-c:a", "aac", "-b:a", "192k", "-t", str(END), "-movflags", "+faststart", out], check=True)
    frame(0, SCENES[0][2]).save(os.path.join(OUT, "サムネイル.png"))
    subprocess.run(["rm", "-rf", TMP])
    print(out)


if __name__ == "__main__":
    main()
