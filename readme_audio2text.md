# Audio to Text

[Audio to Text](https://localai.io/features/audio-to-text/)は、オーディオファイルからテキストを生成する[OpenAI Speech to text API](https://platform.openai.com/docs/guides/speech-to-text)の互換機能。LocalAIから[whisper.cpp](https://github.com/ggerganov/whisper.cpp)を起動しWhisperを実行する。モデルファイルはWhisperの[GGUFモデル](https://huggingface.co/rahalmichel/whisper-ggml/tree/main)を使用する。  

独立したモデルとして実行するため、GPUメモリの十分な空き容量があること。  


<br>
<hr>
<br>

## 環境

### エンドポイント  
HostOSからアクセスする場合
|Function|model|Entpoint|
|:----|:----|:----|
|audio to text|whisper|http://localhost:28000/v1/audio/transcriptions|


### モデル
GGMLに変換されたモデルはファイルを使用する。  
[ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main)に大小複数のモデルファイルがあるので、最適なモデルを選択する。  
Secは、[CM原稿（せっけん）](https://pro-video.jp/voice/announce/)の[001-sibutomo.mp3](https://pro-video.jp/voice/announ、ce/mp3/001-sibutomo.mp3)、23秒のファイルの処理時間。  

|Model|GPU Mem|Sec|GGML|
|:----|:----|:----|:----|
|tiny|532MiB|1.046s|[ggml-tiny.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin)|
|base|690MiB|1.160s|[ggml-base.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin)|
|small|1284MiB|1.602s|[ggml-small.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin)|
|medium|2864MiB|2.872s|[ggml-medium.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin)|
|large|4996MiB|5.232s|[ggml-large.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin)|

変換後のテキスト比較


|Model|Response|
|:----|:----|
|tiny|無店家の社本名ませっけんだら、もう安心。天年の星つせいぶが含まれるため、肌に揺ろう弱いはたえ、少いやかにたもちます。お肌のことでお悩みの方は、ぜひ一度、無店家社本名ませっけんをお試しください。お求めは、01にいゼロ、0.5号号、9号まで。|
|base|無天下のしゃぼん玉石圏なら もう安心天然の保湿成分が含まれるため 肌にうるおよあたえすこやかにたもちますお肌のことでお悩みの方は ぜひ一度無天下しゃぼん玉石圏をお試しくださいおもとめは01,20,00,5,5,9,5まで|
|small|無天下のシャボン生石鹸ならもう安心!天然の保湿成分が含まれるため肌に潤いを与え、少やかに保ちます。お肌のことでお悩みの方は是非一度無天下シャボン生石鹸をお試しください。お求めは0120 0055 95まで|
|medium|無添加のシャボン玉石鹸ならもう安心。天然の保湿成分が含まれるため、肌に潤いを与え、すこやかに保ちます。お肌のことでお悩みの方は、ぜひ一度、無添加シャボン玉石鹸をお試しください。お求めは0120-0055-95まで|
|large|無添加のシャボン玉石鹸ならもう安心!天然の保湿成分が含まれるため、肌にうるおいを与え、健やかに保ちます。お肌のことでお悩みの方は、ぜひ一度、無添加シャボン玉石鹸をお試しください。お求めは、0120-0055-95まで。ありがとうございました|


<br>
<hr>
<br>


## 導入手順

### Dockerイメージ
localaiのffmpeg版のDockerイメージを作成する必要がある。未対応の場合Dockerイメージをリビルドし、` localai-llamacpp`イメージを作成し直すこと。

`Dockerfile`のベースイメージの変更
- Audio to Text(Whisper)を使用する場合はffmpeg版を使う   
- NVIDIA Driverが535以下はcuda-11版を使う 

`Dockerfile`
```
# FROM localai/localai:v2.19.1-cublas-cuda11-ffmpeg
FROM localai/localai:v2.19.1-cublas-cuda12-ffmpeg
# FROM localai/localai:latest-gpu-nvidia-cuda-11
# FROM localai/localai:latest-gpu-nvidia-cuda-12
```
> ffmpeg版はlatest指定が無いため、最新版のバージョンはdockerhubの[localai/localai](https://hub.docker.com/r/localai/localai/tags)で確認する。

#### Dockerのrebuild  
llamacpp.serverをコンパイルし直すため、llama.cppディレクトリを削除する。
```
cd llamacpp-localai
./stop.sh ## Docker停止
rm -fr llama.cpp ## llama.serverの削除（再構築）
## Dockerfileの修正
./build.sh ## リビルド
```


### モデルのダウンロード
[ggml-large-v3.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin)を使用する。

```
cd models/
wget https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin
```


### モデルの追加
Whisperモデル定義ファイル`whisper-1`を`model/`に作成する。`model:`に使用するモデルファイル名を指定する。

`models/whisper-1.yaml`
```
name: whisper-1
backend: whisper
parameters:
  model: ggml-large-v3.bin
```


### LiteLLM Proxy
LiteLLMにエンドポイントの設定を追加する。

`litellm.yaml`
```
  - model_name: whisper-1
    litellm_params:
      model: openai/whisper-1
      api_base: http://localhost:8080/v1
      api_key: None
```

### 実行
`localai-llamacpp`を実行する。
```
run.sh
```

<br>
<hr>
<br>


## 動作確認
Dockerを再起動しHostOSからアクセスする。
初回アクセス時はモデルを起動するため少し時間がかかる。

### コマンドで確認

#### Audioファイルのダウンロード
[サンプル音声/無料ダウンロード](https://pro-video.jp/voice/announce/)の「CM原稿（せっけん）」[001-sibutomo.mp3](https://pro-video.jp/voice/announ、ce/mp3/001-sibutomo.mp3)を使用する。

```
wget https://pro-video.jp/voice/announce/mp3/001-sibutomo.mp3
```

#### 実行

音声ファイルを`multipart/form-data`で送る。
```
curl http://localhost:28080/v1/audio/transcriptions -H "Content-Type: multipart/form-data" -F file="@$PWD/001-sibutomo.mp3" -F model="whisper-1"
```

[実際の音声](https://pro-video.jp/voice/announce/mp3/001-sibutomo.mp3)

レスポンス
```
{
	"segments": [
		{
			"id": 0,
			"start": 880000000,
			"end": 3820000000,
			"text": "無添加のシャボン玉石鹸ならもう安心!",
			"tokens": [
				16976,
				14176,
				119,
				9990,
				2972,
				11054,
				17233,
				37626,
				4824,
				8051,
				231,
				36783,
				47219,
				116,
				42540,
				16324,
				16206,
				7945,
				0,
				50556
			]
		},
		{
			"id": 1,
			"start": 3820000000,
			"end": 10260000000,
			"text": "天然の保湿成分が含まれるため、肌にうるおいを与え、健やかに保ちます。",
			"tokens": [
				6135,
				5823,
				2972,
				24302,
				33744,
				123,
				11336,
				6627,
				5142,
				2392,
				104,
				2889,
				35367,
				49983,
				1231,
				14356,
				234,
				4108,
				2646,
				4895,
				33261,
				5998,
				940,
				236,
				6474,
				1231,
				44201,
				7355,
				3703,
				4108,
				24302,
				6574,
				5368,
				1543,
				50878
			]
		},
		{
			"id": 2,
			"start": 10260000000,
			"end": 16680000000,
			"text": "お肌のことでお悩みの方は、ぜひ一度、無添加シャボン玉石鹸をお試しください。",
			"tokens": [
				6117,
				14356,
				234,
				2972,
				13235,
				2474,
				6117,
				14696,
				102,
				11362,
				2972,
				9249,
				3065,
				1231,
				20258,
				26950,
				2257,
				13127,
				1231,
				16976,
				14176,
				119,
				9990,
				11054,
				17233,
				37626,
				4824,
				8051,
				231,
				36783,
				47219,
				116,
				5998,
				6117,
				22099,
				2849,
				25079,
				1543,
				51199
			]
		},
		{
			"id": 3,
			"start": 16680000000,
			"end": 22400000000,
			"text": "お求めは、0120-0055-95まで。",
			"tokens": [
				6117,
				32718,
				11429,
				3065,
				1231,
				10607,
				2009,
				12,
				628,
				13622,
				12,
				15718,
				28176,
				1543,
				51485
			]
		},
		{
			"id": 4,
			"start": 22400000000,
			"end": 24400000000,
			"text": "ありがとうございました。",
			"tokens": [
				50365,
				38538,
				1543,
				50465
			]
		}
	],
	"text": "無添加のシャボン玉石鹸ならもう安心!天然の保湿成分が含まれるため、肌にうるおいを与え、健やかに保ちます。お肌のことでお悩みの方は、ぜひ一度、無添加シャボン玉石鹸をお試しください。お求めは、0120-0055-95まで。ありがとうございました。"
}
```

#### ファイル形式に関して
mp3(44100Hz,128kb/s), wav(PCM S16LE,16bit,16KHz,mono), ogg(22050Hz,88kb/s,streo)は問題なく動作した。


<hr>

### Python Sample
```
import openai

openai.api_key = "EMPTY" ## Dummy
openai.base_url = 'http://localhost:28000/' ## OpenAI API Endpoint, Dockerからはhost.docker.internal

audio_file = open("001-sibutomo.mp3", "rb")
transcript = openai.audio.transcriptions.create(
  file=audio_file,
  model="whisper-1",
  response_format="verbose_json",
  timestamp_granularities=["word"]
)

print(transcript.text)
```


<br>
<hr>
<br>


## 参考
- [LocalAI Audio to text](https://localai.io/features/audio-to-text/)
- [LocalAI Run with container images](https://localai.io/basics/container/)
- [github ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- [dockerhub localai](https://hub.docker.com/r/localai/localai/tags)
- [OpenAI API Speech to text](https://platform.openai.com/docs/guides/speech-to-text)
- [HuggingFace ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main) - GGMLモデルファイル
- [サンプル音声/無料ダウンロード](https://pro-video.jp/voice/announce/)
<hr>

LLM実行委員会