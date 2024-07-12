# Reranker
<img src="https://i.imgur.com/dQsNajT.png">

[参考](https://secon.dev/entry/2024/04/02/070000-japanese-reranker-release/)

RerankerはRAGの精度向上で使用する。質問文と文章を同じコンテキストで評価するため、ベクトルの類似度よりも質問と文章の関連性を理解したより高い評価が可能。ただし、ベクトルの類似度のように事前に計算しておくことが出来ないため計算コストが高いため、ベクトル類似度や全文検索で多めの候補を抽出し、その候補のみを再ランクすることにより最終的な候補を絞り込むのに使用される。

LocalAIでは[Reranker](https://localai.io/features/reranker/)の機能がサポートされている。実装は[AnswerDotAI/rerankers](https://github.com/AnswerDotAI/rerankers)、APIはOpenAIでは定義されていないため [Cohere](https://litellm.vercel.app/docs/proxy/pass_through)のAPI（たぶん）。  モデルはRerank用にファインチューニングされたものが必要、デフォルトでは[mixedbread-ai/mxbai-rerank-base-v1](https://huggingface.co/mixedbread-ai/mxbai-rerank-base-v1)が使用される。


<br>
<hr>
<br>


## 導入手順
[localai-llamacpp](readme.md)の環境を前提する。

### モデルの追加
`models/`にrerankの定義ファイル`jina-reranker-v1-base-en.yaml`を作成する。

`jina-reranker-v1-base-en.yaml`
```
name: jina-reranker-v1-base-en
backend: rerankers
parameters:
  model: cross-encoder
```

> 他のモデルを使用したい場合
> `model: cross-encoder`を`model: hotchpotch/japanese-reranker-cross-encoder-small-v1`のように、Huggingfaceのモデル名に置き換える。


### LiteLLM Proxyの定義
Re-Rank Endpointをパススルーで追加する。

`litellm.yaml`
```
general_settings:
  pass_through_endpoints:
    - path: "/v1/rerank"
      target: "http://localhost:8080/v1/rerank"
      headers:
        content-type: application/json
        accept: application/json
```

<br>
<hr>
<br>

## 動作確認
Dockerを再起動し、HostOSからアクセスする。
初回アクセス時は、モデルをダウンロード、起動するため少し時間がかかる。


### Rerankにアクセス
「食べ物に関する話」に近い文書をランキングしてみる。
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

#### Rerank結果
relevance_scoreが高いほど関連度が高い。食べ物に関する文章が上位に来る。  

json整形後
```
{
	"model": "jina-reranker-v1-base-en",
	"usage": {
		"total_tokens": 11,
		"prompt_tokens": 1
	},
	"results": [
		{
			"index": 8,
			"document": {
				"text": "昨日の夕食は、自分で作ったカレーライスでした。"
			},
			"relevance_score": -1.533203125
		},
		{
			"index": 1,
			"document": {
				"text": "新しいレストランで食事をして、美味しいパスタを食べました。"
			},
			"relevance_score": -1.9912109375
		},
		{
			"index": 0,
			"document": {
				"text": "昨日は友達と公園でピクニックをしました。"
			},
			"relevance_score": -4.109375
		},
		{
			"index": 5,
			"document": {
				"text": "最近、読書に夢中になっています。"
			},
			"relevance_score": -4.59375
		},
		{
			"index": 9,
			"document": {
				"text": "今日は新しいプロジェクトの打ち合わせがあります。"
			},
			"relevance_score": -4.66796875
		},
		{
			"index": 7,
			"document": {
				"text": "夏休みには家族と一緒に旅行に行きます。"
			},
			"relevance_score": -4.90625
		},
		{
			"index": 2,
			"document": {
				"text": "次の週末には山登りに行く予定です。"
			},
			"relevance_score": -4.96484375
		},
		{
			"index": 4,
			"document": {
				"text": "明日は大事な会議があるので、早く寝るつもりです。"
			},
			"relevance_score": -5.38671875
		},
		{
			"index": 3,
			"document": {
				"text": "昨晩、面白い映画を見ました。"
			},
			"relevance_score": -5.4609375
		},
		{
			"index": 6,
			"document": {
				"text": "彼はスポーツが得意で、特にサッカーが好きです。"
			},
			"relevance_score": -5.84375
		}
	]
}
```

<br>
<hr>
<br>

## Rerankモデル
あまりない💦

- [BAAI/bge-reranker-large](https://huggingface.co/BAAI/bge-reranker-large)  
- [nreimers/mmarco-mMiniLMv2-L12-H384-v1](https://huggingface.co/nreimers/mmarco-mMiniLMv2-L12-H384-v1/tree/main)  
- [hotchpotch/japanese-bge-reranker-v2-m3-v1](https://huggingface.co/hotchpotch/japanese-bge-reranker-v2-m3-v1)  
- [hotchpotch/japanese-reranker-cross-encoder-small-v1](https://huggingface.co/hotchpotch/japanese-reranker-cross-encoder-small-v1)  
    - base/largeモデルは、`You need to install fugashi to use MecabTokenizer`エラーになる。




## 参考
- [日本語最高性能のRerankerをリリース / そもそも Reranker とは?](https://secon.dev/entry/2024/04/02/070000-japanese-reranker-release/)  
- [日本語 Reranker 作成のテクニカルレポート](https://secon.dev/entry/2024/04/02/080000-japanese-reranker-tech-report/)  
- [文書検索におけるリランキングの効果を検証する](https://hironsan.hatenablog.com/entry/information-retrieval-with-reranker)  
- [Google Colab で japanese-reranker-cross-encoder-large-v1 を試す](https://note.com/npaka/n/n906b23636ac8)
- [Sentence BERTをFine TuningしてFAQを類似文書検索してみる](https://acro-engineer.hatenablog.com/entry/2023/01/16/120000#:~:text=Sentence%20BERT%E3%81%A8%E3%81%AF%E3%80%81BERT,%E3%81%A8%E3%81%84%E3%81%86%E5%86%85%E5%AE%B9%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%99%E3%80%82)

<hr>
LLM実行委員回