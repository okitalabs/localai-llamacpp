# localai-llamacpp
gpt-3.5-turbo、text-embedding-ada-002が使用可能なOpenAI API互換サーバを立てる。  
[LocalAI](https://www.bing.com/search?q=localai+github&qs=n&form=QBRE&sp=-1&lq=0&pq=&sc=0-0&sk=&cvid=406D55AEDDED4776B399B8EF9821A6DC&ghsh=0&ghacc=0&ghpl=)のDockerイメージに[LLaMA.cpp HTTP Server](https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md)と[LiteLLM](https://github.com/BerriAI/litellm)も同居した実行環境を構築する。

### 実行方針	
- LocalAIのllamacppは使わない（レスポンスがちょっとおかしくなる事象があるため）
- LLMの実行はllama-server(LLaMA.cpp HTTP Server)を使用する
- LLMのモデルは、Llama-3-ELYZA-JP-8B-Q8_0.ggufを使用する（精度が高くモデルサイズが小さいため、ただし最大コンテキスト長は512token、日本語512文字で400token前後）
- EmbeddingsはSentenceBERT(multilingual-e5-small)をLocalAIのSentenceTransformerで実行する（精度が高くEmbedサイズが小さいため）
- llama-serverのコンパイルはentrypoint.shで行う（docker buildでコンパイルすると実行時に ggml-cuda.cu was compiled for: 520 エラーになるため）
- endpointの一元化にLiteLLM Proxyを使用する
- GPUを使用する（例ではP40/24GB x3台）


### 環境

#### ディレクトリ
|HostOS|Docker|Comment|
|:----|:----|:----|
|/home/users/localai-llamacpp|/localai|設定ファイル置き場|
|/home/users/localai-llamacpp/models|/build/models|モデルファイル置き場|

#### ポート
|HostOS|Docker|Comment|
|:----|:----|:----|
|28000|8000|LiteLLM Proxy Port|
| |8080|LocalAI Port|
| |8090|lllama-server Port|

#### エントリポイント  
HostOSからアクセスする場合
|Function|model|Entrypoint|
|:----|:----|:----|
|Text/Chat Completion|gpt-3.5-turbo|http://localhost:28000/v1/chat/completions|
|Embeddings|text-embedding-ada-002|http://localhost:28000/v1/embeddings|

Docker内実行エンジン
|Function|model|Entrypoint|Engine|
|:----|:----|:----|:----|
|Text/Chat Completion|Llama-3-ELYZA-JP-8B|http://localhost:8090/v1|llama-server|
|Embeddings|multilingual-e5-small|http://localhost:8080/v1|localai|


<br>
<hr>
<br>

## 実行手順

### 1.実行環境のインストール
GitHubのリポジトリを`/home/users/localai-llamacpp`に配置し、shellに実行権限を付ける。
```
git clone https://github.com/okitalabs/localai-llamacpp.git
cp localai-llamacpp /home/users/
chmod +x /home/users/localai-llamacpp/*.sh
```

### 2.LLMモデルファイルのダウンロード
`Llama-3-ELYZA-JP-8B-Q8_0.gguf`を`models/`にダウンロードする。
```
cd /home/users/localai-llamacpp/models
wget https://huggingface.co/mmnga/Llama-3-ELYZA-JP-8B-gguf/resolve/main/Llama-3-ELYZA-JP-8B-Q8_0.gguf
```

### 3. Dockerイメージの作成
Dockerイメージをビルドし、` localai-llamacpp`イメージを作成する。
```
cd /home/users/localai-llamacpp/
./build.sh
```

ビルドイメージの確認。以下の2つがあればOK。
```
$ docker images
REPOSITORY         TAG                         IMAGE ID       CREATED      SIZE
localai-llamacpp   latest                      249482681bbf   2 days ago   44.5GB
localai/localai    latest-gpu-nvidia-cuda-12   be2071271e0d   8 days ago   44.2GB
```

### 4. Dockerの起動

```
./run.sh
```

> - 初回起動時はllama.cppをcloneしてコンパイルが始まる。
> - 2回目以降は`localai-llamacpp/llama.cpp/`に保存されているため、コンパイルしないで起動する。


### 5. 動作確認
HostOSからcurlでアクセスして動作の確認を行う。
#### Chat Completion
```
curl http://localhost:28000/v1/chat/completions \
-H "Content-Type: application/json" \
-H "Authorization: Bearer None" \
-d '{
  "model": "gpt-3.5-turbo",
  "templature": 0.01,
  "top_p": 0.01,
  "messages": [
    {"role": "system", "content": "あなたは優秀な観光ガイドです。"},
    {"role": "user", "content": "自己紹介をしてください"}
  ]
}'
```

### Embeddings
```
curl http://localhost:28000/v1/embeddings \
-H "Content-Type: application/json" \
-H "Authorization: Bearer None" \
-d '{
model: "text-embedding-ada-002",
input: "query: 夕飯はお肉です。"
}' 
```
> - 初回アクセス時はモデルをダンロードするので時間がかかる。
> - ダウンロード後、モデルは`models/models--intfloat--multilingual-e5-small/`にダウロードされている。
> - モデルの指定は、`models/multilingual-e5-small.yaml`を作成して定義する事で、自動的にlocalaiがファイル名をモデル名として認識し、アクセスがあるとモデルをダウンロードして実行する。

### 6. 停止
```
./stop.sh
```
> - docker stop, docker rmを実行しているだけ。


<br>
<hr>
<br>

## モデルの変更
実行するモデルを変更したい場合。

### Text/Chat Completionの変更
- GGUF形式のモデルファイルを`models/`以下にダウンロード。
- `entrypoint.sh`で起動しているllama-serverの設定を変更する。
- Dockerコンテナ内のモデルファイルは`/build/models`に配置される。
- dockerを再起動する。

```
$ cd /home/users/localai-llamacpp/
$ cat entrypoint.sh
 :
## llama-serverの実行
## モデルに応じて --model, --chat-template, --ctx-size, --n-gpu-layersを調整
exec llama-server \
--model /build/models/Llama-3-ELYZA-JP-8B.Q8_0.gguf \
--chat-template llama3 \
--ctx-size 4096 \
--n-gpu-layers 40 \
--parallel 8 \
--threads-batch 8 \
--threads-http 8 \
--cont-batching \
--flash-attn \
--host 0.0.0.0 \
--port 8090 \
> $HOME_DIR/logs/llamacpp.log 2>&1 &
 :
```

#### モデルパラメータ
llama-serverのオプション指標。

|model|Model Size|chat-template|ctx-size|n-gpu-layers|GPU Mem|URL|
|:----|:----|:----|:----|:----|:----|:----|
|DataPilot-ArrowPro-7B-KUJIRA-Q8_0.gguf|7B|mistral|4096|33|8GB|[mmnga/DataPilot-ArrowPro-7B-KUJIRA-gguf](https://huggingface.co/mmnga/DataPilot-ArrowPro-7B-KUJIRA-gguf)|
|Llama-3-ELYZA-JP-8B.Q8_0.gguf|8B|llama3|8192|33|8GB|[mmnga/Llama-3-ELYZA-JP-8B-gguf](https://huggingface.co/mmnga/Llama-3-ELYZA-JP-8B-gguf)|
|vicuna-13b-v1.5.Q8_0.gguf|13B|vicuna|4096|41|14GB|[TheBloke/vicuna-13B-v1.5-GGUF](https://huggingface.co/TheBloke/vicuna-13B-v1.5-GGUF)|
|karakuri-lm-8x7b-instruct-v0.1-Q6_K.gguf|47B|mistral|32768|33|37GB|[ReadyON/karakuri-lm-8x7b-instruct-v0.1-gguf](https://huggingface.co/ReadyON/karakuri-lm-8x7b-instruct-v0.1-gguf)|
|karakuri-lm-70b-chat-v0.1-q4_K_M.gguf|70B|llama2|4096|81|40GB|[mmnga/karakuri-lm-70b-chat-v0.1-gguf](https://huggingface.co/mmnga/karakuri-lm-70b-chat-v0.1-gguf)|

> - GPUメモリは起動時の最低消費量。コンテキスト長により増加する。

### Embeddingsの変更
- `models/`にモデル実行を定義したyamlファイルを配置する。
- ファイル名はアクセスする時のモデル名 + .yaml
- モデルファイルはアクセス時にダウンロードされる
-  intfloat/multilingual-e5-largeをmultilingual-e5-largeとして定義する場合の設定は以下
```
$ cd /home/users/localai-llamacpp/models
$ cat multilingual-e5-large.yaml
name: multilingual-e5-large
backend: sentencetransformers
embeddings: true
parameters:
  model: intfloat/multilingual-e5-large
```

#### モデルパラメータ
|model|Model Size|Score|Embed長|GPU Mem|処理速度|
|:----|:----|:----|:----|:----|:----|
|multilingual-e5-small|0.5B|0.766|384|662|24|
|multilingual-e5-base|1.1B|0.754|768|1316|48|
|multilingual-e5-large|2.3B|0.757|1024|2370|139|
> - Scoreは[客観的Embeddings評価](https://github.com/okitalabs/Embeddings)による計測。
> - Embed長はEmbeddingsのベクトル長
> - 処理速度は512文字、2700件をHuggingFaceEmbeddingsで1件ずつ処理した時の秒数

### Entrypointの変更
- エントリポイントはLiteLLM Proxyで一元化している。
- `litellm.yaml`で定義している。
- yamlのmodelの`openai/`はOpenAI APIでアクセスするという設定。その後にのアクセス先のモデル名となる。
```
$ cd /home/users/localai-llamacpp
$ cat litellm.yaml
model_list:
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: openai/Llama-3-ELYZA-JP-8B
      api_base: http://localhost:8090/v1
      api_key: None
  - model_name: text-embedding-ada-002
    litellm_params:
      model: openai/multilingual-e5-small
      api_base: http://localhost:8080/v1
      api_key: None
```



<br>
<hr>
<br>

## ログ
`logs/`以下に、localai, llama-server, litellmのログが作成されている。ファイルがどんどん大きくなるので注意。  
- ログを出力しない場合、`entrypoint.sh`のリダイレクト先を`/dev/null`に変更する。
- `litellm.log`に、APIのRequest, Responseが記録されるのでやり取りしている内容の確認に便利

```
$ cd /home/users/localai-llamacpp
$ ls logs
litellm.log  llamacpp.log  localai.log
```


<hr>
LLM実行委員会