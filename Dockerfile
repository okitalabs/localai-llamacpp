FROM localai/localai:latest-gpu-nvidia-cuda-12

ENV HOST 0.0.0.0

RUN apt update && apt install -y vim git build-essential libcurl4-openssl-dev

## 必要なライブラリを追加する
## llama-cpp HTTP Server
#WORKDIR /tmp
#RUN apt-get install -y build-essential git libcurl4-openssl-dev
#RUN git clone https://github.com/ggerganov/llama.cpp.git && cd llama.cpp/ && LLAMA_CUDA=1 LLAMA_CURL=1 make llama-server && cp llama-server /usr/local/bin

## LiteLLM Proxy
RUN pip install 'litellm[proxy]'
