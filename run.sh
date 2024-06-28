#!/bin/bash
docker run -itd --gpus all --cap-add SYS_RESOURCE -e USE_MLOCK=0 \
--add-host=host.docker.internal:host-gateway \
--entrypoint /localai/entrypoint.sh \
-p 28000:8000 \
-v /home/users/localai-llamacpp/models:/build/models/ \
-v /home/users/localai-llamacpp:/localai \
-h localai-llamacpp --name localai-llamacpp localai-llamacpp
