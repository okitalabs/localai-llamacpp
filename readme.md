# localai-llamacpp
gpt-3.5-turbo、text-embedding-ada-002が使用可能なOpenAI API互換サーバを立てる。  
[LocalAI](https://www.bing.com/search?q=localai+github&qs=n&form=QBRE&sp=-1&lq=0&pq=&sc=0-0&sk=&cvid=406D55AEDDED4776B399B8EF9821A6DC&ghsh=0&ghacc=0&ghpl=)のDockerイメージに[LLaMA.cpp HTTP Server](https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md)と[LiteLLM](https://github.com/BerriAI/litellm)も同居した実行環境を構築する。  
また、Streamlitによる簡易なチャットを実行する。  
gpt-3.5-turbo(llama-server)はContinuous Batching対応。text-embedding-ada-002(SentenceBERT)はEmbeddingsのベクトル長が384と最軽量な点が特徴。

### 実行方針	
- LocalAIのllamacppは使わない（レスポンスがちょっとおかしくなる事象があるため）。
- LLMの実行はllama-server(LLaMA.cpp HTTP Server)を使用する。
- LLMのモデルは、Llama-3-ELYZA-JP-8B-Q8_0.ggufを使用する（精度が高くモデルサイズが小さいため）。
- EmbeddingsはSentenceBERT(multilingual-e5-small)をLocalAIのSentenceTransformerで実行する（精度がそこそこ高く、モデルサイズが小さく高速で、Embedサイズが小さいため、ただし最大コンテキスト長は512tokenの制限がある。ちなみに、日本語512文字で400token前後）。
- llama-serverのコンパイルはentrypoint.shで行う（docker buildでコンパイルすると実行時に ggml-cuda.cu was compiled for: 520 エラーになるため）。
- endpointの一元化にLiteLLM Proxyを使用する。
- GPUを使用する（例ではP40/24GB x3台）。


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
|28010|8010|Streamlit Chat WebApp|
|28080 |8080|LocalAI Port|
|28090 |8090|lllama-server Port|

#### エンドポイント  
HostOSからアクセスする場合
|Function|model|Entpoint|
|:----|:----|:----|
|Text/Chat Completion|gpt-3.5-turbo|http://localhost:28000/v1/chat/completions|
|Embeddings|text-embedding-ada-002|http://localhost:28000/v1/embeddings|
|Rerank|jina-reranker-v1-base-en|http://localhost:28000/v1/rerank|

Docker内実行エンジン
|Function|model|Endpoint|Engine|
|:----|:----|:----|:----|
|Text/Chat Completion|Llama-3-ELYZA-JP-8B|http://localhost:8090/v1/chat/completions|llama-server|
|Embeddings|multilingual-e5-small|http://localhost:8080/v1/embeddings|localai|
|Rerank|jina-reranker-v1-base-en|http://localhost:8080/v1/rerank|localai|


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

> - 初回起動時はllama.cppをgit cloneしてコンパイルが始まる。コンパイルには時間がかかるためすぐには起動しない。コンパイルの終了は、`top`でコンパイラが走らなくたったか、`logs/`に`chat.log  litellm.log  llamacpp.log  localai.log`の4ファイルが作成されたかで確認する。または、dockerの起動オプションを`-itd`から`-it`にすることでフォアグラウンドで実行するとコンパイル状況を確認できる。
> - 2回目以降は`localai-llamacpp/llama.cpp/`に保存されているため、コンパイルしないで起動する。ただし、モデルのローディングに多少時間がかかる。


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

#### Embeddings
```
curl http://localhost:28000/v1/embeddings \
-H "Content-Type: application/json" \
-H "Authorization: Bearer None" \
-d '{
  "model": "text-embedding-ada-002",
  "input": "query: 夕飯はお肉です。"
}' 
```
> - 初回アクセス時はモデルをダンロードするので時間がかかる。
> - ダウンロード後、モデルは`models/models--intfloat--multilingual-e5-small/`にダウロードされている。
> - モデルの指定は、`models/multilingual-e5-small.yaml`を作成して定義する事で、自動的にlocalaiがファイル名をモデル名として認識し、アクセスがあるとモデルをダウンロードして実行する。


### 6. チャットを使ってみる
HostOSのブラウザで、 `http://localhost:28010/`にアクセスすると、簡易チャット画面が表示される。


### 7. 停止
```
./stop.sh
```
> - docker stop, docker rmを実行しているだけ。


<br>
<hr>
<br>

## モデルの変更
実行するモデルを変更したい場合。

### Text/Chat Completionモデルの変更
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

|Model File|Param|Quant|GPU Mem|chat-template|ctx-size|n-gpu-layers|URL|
|:----|:----|:----|:----|:----|:----|:----|:----|
|DataPilot-ArrowPro-7B-KUJIRA-Q8_0.gguf|7B|8bit|8GB|mistral|4096|33|[mmnga/DataPilot-ArrowPro-7B-KUJIRA-gguf](https://huggingface.co/mmnga/DataPilot-ArrowPro-7B-KUJIRA-gguf)|
|Llama3-ArrowSE-8B-v0.3-Q8_0.gguf|8B|8bit|8GB|llama3|8192|33|[mmnga/Llama3-ArrowSE-8B-v0.3-gguf](https://huggingface.co/mmnga/Llama3-ArrowSE-8B-v0.3-gguf)|
|Llama-3-ELYZA-JP-8B.Q8_0.gguf|8B|8bit|8GB|llama3|8192|33|[mmnga/Llama-3-ELYZA-JP-8B-gguf](https://huggingface.co/mmnga/Llama-3-ELYZA-JP-8B-gguf)|
|vicuna-13b-v1.5.Q8_0.gguf|13B|8bit|14GB|vicuna|4096|41|[TheBloke/vicuna-13B-v1.5-GGUF](https://huggingface.co/TheBloke/vicuna-13B-v1.5-GGUF)|
|calm3-22b-chat-Q6_K.gguf|22B|6bit|18GB|chatml|16384|49|[grapevine-AI/CALM3-22B-Chat-GGUF](https://huggingface.co/grapevine-AI/CALM3-22B-Chat-GGUF)|
|karakuri-lm-8x7b-instruct-v0.1-Q6_K.gguf|47B|6bit|37GB|mistral|32768|33|[ReadyON/karakuri-lm-8x7b-instruct-v0.1-gguf](https://huggingface.co/ReadyON/karakuri-lm-8x7b-instruct-v0.1-gguf)|
|karakuri-lm-70b-chat-v0.1-q4_K_M.gguf|70B|4bit|40GB|llama2|4096|81|[mmnga/karakuri-lm-70b-chat-v0.1-gguf](https://huggingface.co/mmnga/karakuri-lm-70b-chat-v0.1-gguf)|

> - GPUメモリは起動時の最低消費量。コンテキスト長により増加する。


### Embeddingsの変更
Embeddingsのベクトル長が384と最軽量な`multilingual-e5-small`を使用しているが、実践ではより大きいbaseやlargeの方が精度が高い可能性もあるため、変更して検証してみる。
- `models/`にモデル実行を定義したyamlファイルを配置する。
- ファイル名はアクセスする時のモデル名 + .yaml。
- モデルファイルはアクセス時にダウンロードされる。
-  intfloat/multilingual-e5-largeをmultilingual-e5-largeとして定義する場合の設定は以下。
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
|model|Param|Score|Embed長|GPU Mem|処理速度|
|:----|:----|:----|:----|:----|:----|
|intfloat/multilingual-e5-small|0.5B|0.766|384|0.7GB|24|
|intfloat/multilingual-e5-base|1.1B|0.754|768|1.4GB|48|
|intfloat/multilingual-e5-large|2.3B|0.757|1024|2.4GB|139|
> - Scoreは[客観的Embeddings評価](https://github.com/okitalabs/Embeddings)による計測。
> - Embed長はEmbeddingsのベクトル長。
> - 処理速度は512文字、2700件をHuggingFaceEmbeddingsで1件ずつ処理した時の秒数。
> - 実践ではよりモデルの大きい、baseやlargeの方が精度が高い可能性もあるため変更して検証してみる。

### エンドポイントの変更
- エンドポイントはLiteLLM Proxyで一元化している。
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
- `litellm.log`に、APIのRequest, Responseが記録されるのでやり取りしている内容の確認に便利。

```
$ cd /home/users/localai-llamacpp
$ ls logs
litellm.log  llamacpp.log  localai.log
```

<br>
<hr>
<br>

## Reranker
LocalAIでRerankingのAPIを使いたい場合。  
[Reranker](readme_reranker.md)参照。  

設定はGitHubに反映済み。  
以下のコマンドで動作するか確認。
```
curl http://localhost:28000/v1/rerank \
  -H "Content-Type: application/json" \
  -d '{
  "model": "jina-reranker-v1-base-en",
  "query": "食べ物に関する話",
  "documents": [
    "昨日は友達と公園でピクニックをしました。",
    "新しいレストランで食事をして、美味しいパスタを食べました。",
    "次の週末には山登りに行く予定です。",
    "昨晩、面白い映画を見ました。",
    "明日は大事な会議があるので、早く寝るつもりです。",
    "最近、読書に夢中になっています。",
    "彼はスポーツが得意で、特にサッカーが好きです。",
    "夏休みには家族と一緒に旅行に行きます。",
    "昨日の夕食は、自分で作ったカレーライスでした。",
    "今日は新しいプロジェクトの打ち合わせがあります。"
  ],
  "top_n": 3
}'
```

> ### DifyのRerankerの利用時の注意  
> [DiFy](https://github.com/langgenius/dify)の[Rerankモデルの設定](https://docs.dify.ai/v/japanese/guides/knowledge-base/integrate_knowledge_within_application#id-3-zhong-pai-xu-rerank)で、LiteLLMのエンドポイントに接続するとエラーになる。  これは、DiFyの登録確認用のリクエストで`top_n=null`になっているため、LiteLLMのJSonパーサーでエラーになってしまうもよう。  
> Rerankは、直接LocalAIのエントリポイントに接続する。
> 
> |Function|model|Entpoint|
> |:----|:----|:----|
> |Rerank|jina-reranker-v1-base-en|http://localhost:28080/v1/embeddings|

<br>
<hr>
<br>

## GPT Vision
[GPT Vision](https://localai.io/features/gpt-vision/)は、GPT-4oで使用可能な画像からテキストを生成する[OpenAI Vision API](https://platform.openai.com/docs/guides/vision)の互換機能。  
[GPT Vision](readme_vision)参照。

text/chat completionとは別に実行するため、メモリの十分な空き容量があること。  

> デフォルトでは設定されていないため、使用する場合設定を追加すること。

<hr>

LLM実行委員会