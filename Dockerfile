FROM localai/localai:latest-gpu-nvidia-cuda-12

ENV HOST 0.0.0.0

RUN apt update && apt install -y vim git build-essential libcurl4-openssl-dev

## LiteLLM Proxy, streamlit
RUN pip install 'litellm[proxy]' streamlit
