#!/bin/bash
set -e

cd /build

# If we have set EXTRA_BACKENDS, then we need to prepare the backends
if [ -n "$EXTRA_BACKENDS" ]; then
    echo "EXTRA_BACKENDS: $EXTRA_BACKENDS"
    # Space separated list of backends
    for backend in $EXTRA_BACKENDS; do
        echo "Preparing backend: $backend"
        make -C $backend
    done
fi

if [ "$REBUILD" != "false" ]; then
    rm -rf ./local-ai
    make build -j${BUILD_PARALLELISM:-1}
else
    echo "@@@@@"
    echo "Skipping rebuild"
    echo "@@@@@"
    echo "If you are experiencing issues with the pre-compiled builds, try setting REBUILD=true"
    echo "If you are still experiencing issues with the build, try setting CMAKE_ARGS and disable the instructions set as needed:"
    echo 'CMAKE_ARGS="-DLLAMA_F16C=OFF -DLLAMA_AVX512=OFF -DLLAMA_AVX2=OFF -DLLAMA_FMA=OFF"'
    echo "see the documentation at: https://localai.io/basics/build/index.html"
    echo "Note: See also https://github.com/go-skynet/LocalAI/issues/288"
    echo "@@@@@"
    echo "CPU info:"
    grep -e "model\sname" /proc/cpuinfo | head -1
    grep -e "flags" /proc/cpuinfo | head -1
    if grep -q -e "\savx\s" /proc/cpuinfo ; then
        echo "CPU:    AVX    found OK"
    else
        echo "CPU: no AVX    found"
    fi
    if grep -q -e "\savx2\s" /proc/cpuinfo ; then
        echo "CPU:    AVX2   found OK"
    else
        echo "CPU: no AVX2   found"
    fi
    if grep -q -e "\savx512" /proc/cpuinfo ; then
        echo "CPU:    AVX512 found OK"
    else
        echo "CPU: no AVX512 found"
    fi
    echo "@@@@@"
fi

#exec ./local-ai "$@" ## ここでは実行しない


## ここから追加
HOME_DIR=/localai ## llama.cppをダウンロードするディレクトリ

## localaiの起動
exec ./local-ai > $HOME_DIR/logs/localai.log 2>&1 & 

## llama-serverのコンパイル
## $LLAMACPP_DIRが無ければllama.cppをgit clone
## $LLAMACPP_DIR/llama-serverが無ければmakeして/usr/local/binにコピー
LLAMACPP_DIR=$HOME_DIR/llama.cpp

if [ ! -e  $LLAMACPP_DIR/llama-server ]; then
  if [ ! -d $LLAMACPP_DIR ]; then
    echo "hoge"
    cd $HOME_DIR &&  git clone https://github.com/ggerganov/llama.cpp.git
  fi
  cd $LLAMACPP_DIR && LLAMA_CUDA=1 LLAMA_CURL=1 make llama-server
fi

cp $LLAMACPP_DIR/llama-server /usr/local/bin

## llama-serverの実行
## モデルに応じて --model, --chat-template, --ctx-size, --n-gpu-layersを調整
exec llama-server \
--model /build/models/Llama-3-ELYZA-JP-8B-Q8_0.gguf \
--chat-template llama3 \
--ctx-size 8192 \
--n-gpu-layers 33 \
--parallel 8 \
--threads-batch 8 \
--threads-http 8 \
--cont-batching \
--flash-attn \
--host 0.0.0.0 \
--port 8090 \
> $HOME_DIR/logs/llamacpp.log 2>&1 &


## litellm proxy
exec litellm --config $HOME_DIR/litellm.yaml --detailed_debug --port 8000 -- > $HOME_DIR/logs/litellm.log 2>&1 &


## chat
exec streamlit run $HOME_DIR/chat.py --server.port 8010 > $HOME_DIR/logs/chat.log 2>&1 &

/bin/bash
