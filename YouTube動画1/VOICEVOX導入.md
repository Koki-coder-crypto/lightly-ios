# VOICEVOX（ずんだもん）の導入手順 — Linux / Python

GitHubのリリースから直接取得します（APIを使う公式ダウンローダーが使えない環境向け）。

```bash
mkdir -p /opt/voicevox/vv && cd /opt/voicevox
G=https://github.com/VOICEVOX
curl -fLO $G/voicevox_core/releases/download/0.17.1/voicevox_core-0.17.1-cp310-abi3-manylinux_2_34_x86_64.whl
pip install voicevox_core-0.17.1-cp310-abi3-manylinux_2_34_x86_64.whl
cd vv
curl -fL -o ort.tgz $G/onnxruntime-builder/releases/download/voicevox_onnxruntime-1.17.3/voicevox_onnxruntime-linux-x64-1.17.3.tgz
curl -fL -o 0.vvm   $G/voicevox_vvm/releases/download/0.17.1/0.vvm      # ずんだもん・四国めたん等
curl -fL -o dic.tgz https://github.com/r9y9/open_jtalk/releases/download/v1.11.1/open_jtalk_dic_utf_8-1.11.tar.gz
tar xzf ort.tgz && tar xzf dic.tgz
```

`/opt/voicevox/tts.py`（`make_video.py` が呼び出す合成スクリプト）:

```python
import sys, glob
from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile
so = glob.glob("/opt/voicevox/vv/voicevox_onnxruntime-*/lib/libvoicevox_onnxruntime.so*")[0]
syn = Synthesizer(Onnxruntime.load_once(filename=so), OpenJtalk(glob.glob("/opt/voicevox/vv/open_jtalk_dic_utf_8-*")[0]))
with VoiceModelFile.open("/opt/voicevox/vv/0.vvm") as m:
    syn.load_voice_model(m)
    if sys.argv[1] == "list":
        for c in m.metas: print(c.name, [(s.name, s.id) for s in c.styles]); sys.exit()
    style, text, out = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    q = syn.create_audio_query(text, style); q.speed_scale = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    open(out, "wb").write(syn.synthesis(q, style))
```

話者ID（0.vvm）: ずんだもん ノーマル3 / あまあま1 / ツンツン7 / セクシー5、四国めたん ノーマル2、春日部つむぎ8、雨晴はう10

## 利用規約メモ
- 動画の概要欄などに **「VOICEVOX:ずんだもん」** のクレジット表記が必要（商用・収益化OK）。
- ずんだもんのキャラクター利用ガイドラインも守ること（公式サイトで最新版を確認）。
