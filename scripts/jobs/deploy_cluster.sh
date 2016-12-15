#!/bin/bash -ex

HELPERS_DIR="$(dirname "$0")/../"
source $HELPERS_DIR/helpers.sh

ISO_FILE=${ISO_URL##*/}
ISO_FILE=${ISO_FILE%.torrent}

#FUEL-QA options
ENV_NAME=${BUILD_USER_ID}-${DEP_NAME}
ISO_PATH=""
VENV_PATH=''

#DEVOPS options
export PUBLIC_FORWARD="route" #if not specified default is nat
# Rather than exporting it here for all server, this is exported from
# /etc/profile.d/fuel_main.sh on specific server only
#export USE_HUGEPAGES="True"

MAX_ENV_PER_USER="3"
FUEL_PUB_IP=""
PUB_GATEWAY=""
PUB_NET_PREFIX=""
FUEL_ADM_IP=""

MOS_RELEASE=${MOS_RELEASE:-'mos-master'}

for param in ${ADDITIONAL_PARAMETERS}; do
  export ${param}
done

VENV_PATH="/home/jenkins/venv-${MOS_RELEASE}"

FUEL_QA_PATH="${VENV_PATH}/fuel-qa"

. ${VENV_PATH}/bin/activate
. /etc/profile.d/fuel-main.sh

dos.py sync

#Check maximum ENV per user
checkQuotas "${BUILD_USER_ID}"

#Check if we have to build env on SSD
if [[ ${USE_SSD} == 'true' ]]; then
  export STORAGE_POOL_NAME='ssd'
fi

#Download iso and export ISO_PATH
getISO "$ISO_URL"

# Build env
cd ${FUEL_QA_PATH}

#git pull

dos.py version
./utils/jenkins/system_tests.sh -t test -w $(pwd) -j fuelweb_test -i $ISO_PATH  -e $ENV_NAME -o --group=setup -V ${VENV_PATH}


#Get Fuel adm IP
FUEL_ADM_IP=$(virsh net-dumpxml ${ENV_NAME}_admin | grep -P "(\d+\.){3}" -o | awk '{print ""$0"2"}')
#Get pub net
PUB_NET=$(dos.py net-list $ENV_NAME |grep "public" | grep -P "(\d+\.){3}(\d+)" -o )
#Get pub net prefix
PUB_NET_PREFIX=$(dos.py net-list $ENV_NAME |grep "public" | awk '{print $2}' |cut -d "/" -f 2)
#Get pub net last octet
PUB_LAST_OCTET=$(expr ${PUB_NET##*.} + 2)
#Get pub first IP - Gateway
PUB_GATEWAY=$(virsh net-dumpxml ${ENV_NAME}_public | grep -P "(\d+\.){3}(\d+)" -o)
#Get pub net second IP - Fuel
FUEL_PUB_IP=$(virsh net-dumpxml ${ENV_NAME}_public | grep -P "(\d+\.){3}" -o | awk '{print $0}')${PUB_LAST_OCTET}


#dos.py start $ENV_NAME
#dos.py revert-resume $ENV_NAME empty
dos.py start $ENV_NAME

addPublicToFuel "${FUEL_ADM_IP}" "${FUEL_PUB_IP}" "${PUB_NET_PREFIX}" "${PUB_GATEWAY}"

showEnvInfo "${ENV_NAME}" "${FUEL_PUB_IP}"
