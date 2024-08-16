## 使用するDockerイメージの選択
## Audio to Text(Whisper)を使用する場合はffmpeg版を使う
## NVIDIA Driverが535以下はcuda-11版を使う
# FROM localai/localai:v2.19.1-cublas-cuda11-ffmpeg
# FROM localai/localai:v2.19.1-cublas-cuda12-ffmpeg
# FROM localai/localai:latest-gpu-nvidia-cuda-11
FROM localai/localai:latest-gpu-nvidia-cuda-12


ENV HOST 0.0.0.0

RUN apt update && apt install -y vim git build-essential libcurl4-openssl-dev

## LiteLLM Proxy, streamlit
RUN pip install 'litellm[proxy]' streamlit boto3
