#!/bin/bash -ex
source /home/jenkins/venv-mos-master/bin/activate

dos.py sync

ENV_NAME=${BUILD_USER_ID}-${DEP_NAME}

echo "List of ENVs for ${BUILD_USER_ID}"

dos.py list |grep "${BUILD_USER_ID}"

echo "Erasing cluster ${ENV_NAME}"

dos.py erase ${ENV_NAME}
