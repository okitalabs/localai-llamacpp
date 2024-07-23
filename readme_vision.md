# GPT Vision

[GPT Vision](https://localai.io/features/gpt-vision/)は、GPT-4oの機能である、画像からテキストを生成する[OpenAI Vision API](https://platform.openai.com/docs/guides/vision)の互換機能。LocalAIからllama-cppを起動し、LLaVAモデルを実行する。実行には、画像を認識するモデルと、言語を生成する2つのモデルを使用する。


text/chat completionとは別に実行するため、メモリの十分な空き容量があること。

<br>
<hr>
<br>

## 環境
### エンドポイント
HostOSからアクセスする場合
|Function|model|Entpoint|
|:----|:----|:----|
|Vision|llava|http://localhost:28000/v1/chat/completions|


### モデル
|Function|Model Name|
|:----|:----|
|Text|[ggml-model-q4_k.gguf](https://huggingface.co/mys/ggml_llava-v1.5-7b/blob/main/ggml-model-q4_k.gguf)|
|Image|[mmproj-model-f16.gguf](https://huggingface.co/mys/ggml_llava-v1.5-7b/blob/main/mmproj-model-f16.gguf)|

起動時のメモリ使用量: 8246MiB

<br>
<hr>
<br>


## 導入手順
LocalAIの[llava examples](https://github.com/mudler/LocalAI/blob/master/examples/configurations/llava/)を参考に、そのまま適用している。ベースのモデルは [mys/ggml_llava-v1.5-7b](https://huggingface.co/mys/ggml_llava-v1.5-7b)、日本語で質問すると日本語で回答する。

### モデルのダウンロード
`ggml-model-q4_k.gguf`と`mmproj-model-f16.gguf`を`models/`にダウンロードする。

```
cd models/

wget https://huggingface.co/mys/ggml_llava-v1.5-7b/blob/main/ggml-model-q4_k.gguf

wget https://huggingface.co/mys/ggml_llava-v1.5-7b/blob/main/mmproj-model-f16.gguf
```


### モデルの追加
LLaVA用のチャットフォーマットを定義したテンプレートとモデル定義ファイルを`model/`に作成する。

#### チャットテンプレート
`models/llava.tmpl`
```
A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.
{{.Input}}
ASSISTANT:
```

#### モデル定義
`models/llava.yaml`
```
backend: llama-cpp
context_size: 4096
f16: true
threads: 11
gpu_layers: 90
mmap: true
name: llava
roles:
  user: "USER:"
  assistant: "ASSISTANT:"
  system: "SYSTEM:"
parameters:
  model: ggml-model-q4_k.gguf
  temperature: 0.2
  top_k: 40
  top_p: 0.95
template:
  chat: llava
mmproj: mmproj-model-f16.gguf
```


### LiteLLM Proxy
LiteLLMにエンドポイントの設定を追加する。

`litellm.yaml`
```
  - model_name: llava
    litellm_params:
      model: openai/llava
      api_base: http://localhost:8080/v1
      api_key: None
```

<br>
<hr>
<br>


## 動作確認
Dockerを再起動し、HostOSからアクセスする。
初回アクセス時は、モデルをダウンロード、起動するため少し時間が
かかる。

### コマンドで確認
`text`に質問。`image_url`に画像のURLを指定する。
```
curl http://localhost:28000/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "llava",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "どんな画像ですか？"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "https://github.com/go-skynet/LocalAI/assets/2420543/0966aa2a-166e-4f99-a3e5-6c915fc997dd"
          }
        }
      ],
      "temperature": 0.9
    }
  ]
}'
```

実際の画像
<img src="https://github.com/go-skynet/LocalAI/assets/2420543/0966aa2a-166e-4f99-a3e5-6c915fc997dd">

レスポンス
```
{
	"id": "087bf613-1a03-4e7d-ac2c-a10c65e03f5e",
	"choices": [
		{
			"finish_reason": "stop",
			"index": 0,
			"message": {
				"content": "\nこの画像は、青いグラデーションで描かれた、眼鏡をかけたラマという動物のイラストレーションです。ラマは、青いネットを滑るように描かれており、その際には複数の色が使われています。ラマは、眼鏡をかけていることから、かわいく描かれています。</s>",
				"role": "assistant"
			}
		}
	],
	"created": 1721389775,
	"model": "llava",
	"object": "chat.completion",
	"system_fingerprint": null,
	"usage": {
		"completion_tokens": 138,
		"prompt_tokens": 1,
		"total_tokens": 139
	}
}
```

<hr>

### Python Sample
#### 画像URLで指定
```
import openai

openai.api_key = 'EMPTY' ## Dummy
openai.base_url = 'http://host.docker.internal:28000/v1/' ## OpenAI API Endpoint

response = openai.chat.completions.create(
  model='llava',
  messages=[
    {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': '日本語で答えてください。どんな風景ですか？'},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
          },
        },
      ],
    }
  ],
  max_tokens=300,
)

print(response.choices[0])
```

### 画像ファイルを送信
```
import base64
import requests

def encode_image(image_path):
  with open(image_path, 'rb') as image_file:
    return base64.b64encode(image_file.read()).decode('utf-8')

# Path to your image
image_path = 'image.jpg'

# Getting the base64 string
base64_image = encode_image(image_path)

headers = {
  'Content-Type': 'application/json',
  # 'Authorization': f'Bearer {api_key}'
}

payload = {
  'model': 'llava',
  'messages': [
    {
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': '日本語で答えてください。\n人物は登場しますか？、男女どちらですか？、服は何色ですか？'
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': f'data:image/jpeg;base64,{base64_image}'
          }
        }
      ]
    }
  ],
  'max_tokens': 300
}

response = requests.post('http://host.docker.internal:28000/v1/chat/completions', headers=headers, json=payload)
print(response.json())
```


<br>
<hr>
<br>


## 参考
- [LocalAI GPT Vision](https://localai.io/features/gpt-vision/)
- [OpenAI Vision API](https://platform.openai.com/docs/guides/vision)
- [LocalAI/examples/configurations/llava/](https://github.com/mudler/LocalAI/blob/master/examples/configurations/llava/llava.yaml)
- [mys/ggml_llava-v1.5-7b](https://huggingface.co/mys/ggml_llava-v1.5-7b
)
<hr>

LLM実行委員会
