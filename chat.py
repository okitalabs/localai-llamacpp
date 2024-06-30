"""
Simple Chat streamlit Web APP

pip install streamlit
streamlit run chat.py --server.port 8010
"""
from openai import OpenAI
import streamlit as st

base_url = 'http://localhost:8000/v1' ## LLM先(llama-cpp.server)
api_key = 'Dummy' ## Dummy Key 何でも良い
model = 'gpt-3.5-turbo' ## LLM Model Name: gpt-3.5-turbo, text-davinci-003

system = 'あなた日本語の優秀なアシスタントです。'
max_tokens = 4095 ## 生成するトークンの最大数
temperature = 0.9 ## 0～2 直が高いほど多様性が高まる（確率の低い値も選択範囲に入る）
top_p = 0.9 ## 0～1 確率が高い順に上位何%を選択範囲に入れるか
frequency_penalty = 0.0 ## -2～2 モデルが同じ行を逐語的に繰り返す可能性を低下させる
presence_penalty = 0.0 ## -2～2 モデルが新しいトピックについて話す可能性を高める
seed = 0 ## 乱数の初期値 出力結果を一定にする

## サーバと接続
openai = OpenAI(
    base_url=base_url, ## Model Name
    api_key=api_key ## Dummy Key
)

## Streamit GUI
st.set_page_config(page_title='Simple Chat')  ## ページタイトル
st.title('Simple Chat') ## タイトル

## サイドバー
st.sidebar.markdown('# Model Parameters')
max_tokens = st.sidebar.number_input('Max Tokens', 0, 4096, max_tokens, step=256) ## Max Tokens
temperature = st.sidebar.slider('Temperature', 0.0, 2.0, temperature, 0.1) ## Temperature
top_p = st.sidebar.slider('Top P', 0.1, 1.0, top_p, 0.1) ## Top P
if st.sidebar.button('Clear Chat', use_container_width=True): ## Clear Chat Button
    ## 画面と履歴のクリア
    print('Clear Chat')
    st.session_state.messages = [] ## これで履歴も消える！！

## 初期設定
if 'openai_model' not in st.session_state:
    st.session_state['openai_model'] = model

if 'messages' not in st.session_state:
    st.session_state.messages = []
    # st.session_state.messages.append({"role": "system", "content": system}) ## システムプロンプトを使う場合

for message in st.session_state.messages:
    with st.chat_message(message['role']):
        st.markdown(message['content'])

if prompt := st.chat_input('何か質問してください'):
    ## 入力後の処理
    st.session_state.messages.append({'role': 'user', 'content': prompt})
    with st.chat_message('user'):
        st.markdown(prompt)

    ## OpenAI API ChatCompletion
    with st.chat_message('assistant'):
        stream = openai.chat.completions.create(
            model=st.session_state['openai_model'],
            max_tokens=max_tokens, temperature=temperature, top_p=top_p, seed=seed,
            frequency_penalty=frequency_penalty, presence_penalty=presence_penalty,
            messages=[
                {'role': m['role'], 'content': m['content']}
                for m in st.session_state.messages ## ここで履歴を挿入している
            ],
            stream=True,
        )
        response = st.write_stream(stream) ## Streamの表示

    ## 出力後の処理
    st.session_state.messages.append({'role': 'assistant', 'content': response})
    print('max_tokens:', max_tokens, 'temperature:', temperature, 'top_p:', top_p)
    print(st.session_state.messages)