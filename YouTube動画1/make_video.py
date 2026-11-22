#!/usr/bin/env python3
"""YouTube動画1（v2）を組み立てるスクリプト。

参考にした形式：顔出しなし雑学ショート（例：109万回再生の「日々のひと息雑学」）
  - 上部の黒帯に固定タイトル（白＋黄色の太字）
  - 中央の白い枠に、黒/赤の太字字幕 ＋ ゆるいクリップアート
  - 一文ごとにハードカットでイラストが切り替わる
  - 落ち着いた女性ナレーション ＋ 控えめなBGM

素材（素材/ フォルダ）：
  img0〜6.png … Higgsfield（gpt_image_2_6）で生成したイラスト
ナレーション … VOICEVOX（ずんだもん ノーマル）でこのスクリプトが生成
               クレジット表記「VOICEVOX:ずんだもん」を画面下と概要欄に入れること
使い方：python3 make_video.py
必要: ffmpeg, numpy, Pillow, IPAゴシック, voicevox_core(0.17) と /opt/voicevox/tts.py
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
# (イラスト番号, 字幕[(文字, 色)], ずんだもんのセリフ)
SCENES = [
    (0, [("毎日使っているあれも", BLK), ("実は日本生まれなのだ！", RED)],
     "毎日使ってるあれも、実は日本生まれなのだ！"),
    (1, [("まずは「新幹線」", RED), ("1964年開業の世界初の高速鉄道", BLK)],
     "まずは新幹線。千九百六十四年に開業した、世界初の高速鉄道なのだ。"),
    (2, [("次は「カラオケ」", RED), ("1970年代に神戸のバンドマンが生み出した", BLK)],
     "次はカラオケ。千九百七十年代に、神戸のバンドマンが生み出したのだ。"),
    (3, [("「インスタントラーメン」は1958年", RED), ("チキンラーメンとして誕生", BLK)],
     "インスタントラーメンは千九百五十八年、チキンラーメンとして誕生したのだ。"),
    (4, [("「絵文字」は1999年", RED), ("たった176個から始まった", BLK)],
     "絵文字は千九百九十九年、たった百七十六個から始まったのだ。"),
    (5, [("そして「QRコード」", RED), ("1994年に日本のデンソーウェーブが開発", BLK)],
     "そしてキューアールコード。千九百九十四年に、日本のデンソーウェーブが開発したのだ！"),
    (6, [("いくつ知ってた？", RED), ("コメントで教えてね", BLK)],
     "いくつ知ってたか、コメントで教えてほしいのだ！"),
]
ZUNDAMON = 3      # ずんだもん ノーマル
SPEED = 1.15
GAP = 0.25        # 文と文の間
LEAD = 0.3        # 冒頭の無音
CREDIT = "VOICEVOX:ずんだもん"


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
    d.text((W - 40, H - 60), CREDIT, font=ImageFont.truetype(FONT, 40), fill=(200, 200, 200), anchor="rd")
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


def voice():
    """一文ずつずんだもんで合成し、1本につなげる。各文の開始秒を返す。"""
    sr = 24000
    parts, starts, pos = [np.zeros(int(LEAD * sr), np.int16)], [], LEAD
    for i, (_, _, say) in enumerate(SCENES):
        p = os.path.join(TMP, f"v{i}.wav")
        subprocess.run(["python3", "/opt/voicevox/tts.py", str(ZUNDAMON), say, p, str(SPEED)], check=True)
        with wave.open(p) as w:
            sr = w.getframerate()
            a = np.frombuffer(w.readframes(w.getnframes()), np.int16)
        starts.append(pos)
        parts += [a, np.zeros(int(GAP * sr), np.int16)]
        pos += len(a) / sr + GAP
    with wave.open(os.path.join(TMP, "voice.wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(np.concatenate(parts).tobytes())
    return starts, pos + 0.6


def main():
    os.makedirs(TMP, exist_ok=True)
    starts, end = voice()
    starts[0] = 0.0
    with open(os.path.join(TMP, "list.txt"), "w") as fo:
        for i, (img, lines, _) in enumerate(SCENES):
            frame(img, lines).save(os.path.join(TMP, f"s{i}.png"))
            nxt = starts[i + 1] if i + 1 < len(SCENES) else end
            fo.write(f"file 's{i}.png'\nduration {nxt - starts[i]:.3f}\n")
        fo.write(f"file 's{len(SCENES) - 1}.png'\n")
    bgm(os.path.join(TMP, "bgm.wav"), end)
    out = os.path.join(OUT, "YouTube動画1_日本発祥の世界的発明5選.mp4")
    subprocess.run([
        "ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-i", os.path.join(TMP, "list.txt"),
        "-i", os.path.join(TMP, "voice.wav"), "-i", os.path.join(TMP, "bgm.wav"),
        "-filter_complex",
        "[0:v]fps=30,format=yuv420p[v];[2:a]volume=0.18[a2];"
        "[1:a][a2]amix=inputs=2:duration=longest:normalize=0,loudnorm=I=-14:TP=-1.5[a]",
        "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "18", "-preset", "medium",
        "-c:a", "aac", "-b:a", "192k", "-t", f"{end:.2f}", "-movflags", "+faststart", out], check=True)
    frame(0, SCENES[0][1]).save(os.path.join(OUT, "サムネイル.png"))
    subprocess.run(["rm", "-rf", TMP])
    print(out, f"{end:.1f}s")


if __name__ == "__main__":
    main()
