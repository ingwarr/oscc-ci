#!/bin/bash

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
IFCFG_PATH="/etc/sysconfig/network-scripts"

DOWNLOAD_DIR="/srv/downloads"
ARIA_OPTS="--seed-time=0 --allow-overwrite=true --force-save=true --auto-file-renaming=false  --allow-piece-length-change=true"

MAX_ENV_PER_USER="3"

#TESTRAIL PARAMS
FUEL_QA_PATH='/usr/share/fuel-qa/'
JENKINS_URL='https://oscc-jenkins-cc.vm.mirantis.net'
#TESTRAIL_USER=
#TESTRAIL_PASSWORD=

function waitForSSH {
  local server_ip="$1"
  local BOOT_TIMEOUT=180
  local CHECK_TIMEOUT=30
  local cur_time=0

  LOG_FINISHED="1"
  while [[ "${LOG_FINISHED}" == "1" ]]; do
    sleep $CHECK_TIMEOUT
    time=$(($cur_time+$CHECK_TIMEOUT))
    LOG_FINISHED=$(nc -w 2 $server_ip 22; echo $?)
    if [ ${cur_time} -ge $BOOT_TIMEOUT ]; then
      echo "Can't get to VM in $BOOT_TIMEOUT sec"
      exit 1
    fi
  done
}

function addPublicToFuel {
  FUEL_ADM_IP="$1"
  FUEL_PUB_IP="$2"
  PUB_NET_PREFIX="$3"
  PUB_GATEWAY="$4"

  SSH_CMD="sshpass -p r00tme ssh ${SSH_OPTS} root@${FUEL_ADM_IP}"

  waitForSSH "$FUEL_ADM_IP"

  PUB_INTERFACE=$(${SSH_CMD} 'ifconfig -a ' | grep -E "(flags=|Link encap)" |grep -v  "docker" | sed '2!d' | awk {'print $1'} | cut -d ":" -f1)
  IFCFG_PUB_FILE="$IFCFG_PATH/ifcfg-$PUB_INTERFACE"

  ${SSH_CMD} "sed -i "s/ONBOOT=no/ONBOOT=yes/" ${IFCFG_PUB_FILE};
              sed -i "s/BOOTPROTO=dhcp/BOOTPROTO=static/" ${IFCFG_PUB_FILE};
              sed -i "s/NM_CONTROLLED=yes/NM_CONTROLLED=no/" ${IFCFG_PUB_FILE};
              sed -i "s/IPADDR=.*/IPADDR=$FUEL_PUB_IP/" ${IFCFG_PUB_FILE}; grep -q "IPADDR" ${IFCFG_PUB_FILE} || echo "IPADDR=$FUEL_PUB_IP" >> ${IFCFG_PUB_FILE};
              sed -i "s/PREFIX=.*/PREFIX=$PUB_NET_PREFIX/" ${IFCFG_PUB_FILE}; grep -q "PREFIX" ${IFCFG_PUB_FILE} || echo "PREFIX=$PUB_NET_PREFIX" >> ${IFCFG_PUB_FILE};
              sed -i "s/GATEWAY/\#GATEWAY/" $IFCFG_PATH/ifcfg-*;
              sed -i "s/GATEWAY=.*/GATEWAY=$PUB_GATEWAY/" /etc/sysconfig/network; grep -q "GATEWAY" /etc/sysconfig/network || echo "GATEWAY=$PUB_GATEWAY" >> ${IFCFG_PUB_FILE};
              /etc/init.d/network restart;
  "

  ${SSH_CMD} "/etc/init.d/network restart;"

  # SSH Listen on all interfaces
  ${SSH_CMD} "sed -i 's/ListenAddress.*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config;
              service sshd restart;
             "

  # Wait for SSH
  sleep 10

  # Open SSH port for Public network
  ${SSH_CMD} "iptables -I INPUT -p tcp -i $PUB_INTERFACE --dport 22 -j ACCEPT;
              iptables-save > /etc/sysconfig/iptables.save;
              "
}

function showEnvInfo {
  ENV_NAME="$1"
  FUEL_PUB_IP="$2"
  PUB_NET=$(dos.py net-list $ENV_NAME |grep "public" | awk '{print $2}')
  set +x
  echo "################################################################################################"
  echo "###################################  Environment Info: #########################################"
  echo "################################################################################################"
  echo -e "\n"
  echo "Fuel IP: http://${FUEL_PUB_IP}:8000"
  echo -e "\n"
  dos.py net-list $ENV_NAME
  echo -e "\n"
  dos.py show $ENV_NAME
  echo -e "\n"
  echo "Public NET:"
  ipcalc -b $PUB_NET |egrep "Network:|HostMin:|HostMax:"
}


function getISO {
  ISO_URL="$1"
  ISO_FILE=${ISO_URL##*/}
  ISO_FILE=${ISO_FILE%.torrent}

  #Download iso and export ISO_PATH
  aria2c -d ${DOWNLOAD_DIR} ${ARIA_OPTS} $ISO_URL
  ISO_PATH="/srv/downloads/${ISO_FILE}"

}

function checkQuotas {
  BUILD_USER_ID="$1"
  if [[ $(dos.py list |grep "${BUILD_USER_ID}" | wc -l) -ge ${MAX_ENV_PER_USER} ]]; then
    echo "[ERROR]: Maximum ENV per user is 3"
    exit 1
  fi

}

function testrail_results {
  local FUEL_IP="$1"
  local TEMPEST_REPORT_PATH="$2"

  nailgun_cl_cmd="import sys; sys.path.append('${FUEL_QA_PATH}');from fuelweb_test.models import nailgun_client;client = nailgun_client.NailgunClient('${FUEL_IP}')"

  export TESTRAIL_USER=${TESTRAIL_USER}
  export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}
  export TESTRAIL_MILESTONE=$(python -c "${nailgun_cl_cmd};print str(client.get_api_version()['release'])")
  export TESTRAIL_TEST_SUITE="Tempest ${TESTRAIL_MILESTONE}"
  export JENKINS_URL=${JENKINS_URL}
  local ISO=$(python -c "${nailgun_cl_cmd};print str(client.get_api_version()['build_number'])")
  local RELEASE=$(python -c "import sys; sys.path.append('$(dirname "$0")'); import helpers; helpers.printClusterRelease('${FUEL_IP}')")
  local CLUSTER_CONF=$(python -c "import sys; sys.path.append('/home/jenkins/oscc-ci/scripts/'); import helpers; helpers.printClusterAttributes('${FUEL_IP}')")
    {
    echo "######################################################"
    if ${env_success}; then
        echo "Add tempest result to testrail                        "
    else
        echo "Marked all tempest tests as fails because env has ERROR state"
    fi
    echo "######################################################"
    echo "Variables for testrail                                "
    echo "######################################################"
    echo "TESTRAIL_USER=${TESTRAIL_USER}                        "
    echo "TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD:0:3}*********** "
    echo "TESTRAIL_TEST_SUITE=${TESTRAIL_TEST_SUITE}            "
    echo "TESTRAIL_MILESTONE=${TESTRAIL_MILESTONE}              "
    echo "JENKINS_URL=${JENKINS_URL}                            "
    echo "ISO=${ISO}                                            "
    echo "RELEASE=${RELEASE}                                    "
    echo "TEMPEST_REPORT_PATH=${TEMPEST_REPORT_PATH}            "
    echo "CLUSTER_CONF=${CLUSTER_CONF}                                        "
    echo "######################################################"
    echo
    }

    source /home/jenkins/venv-nailgun-tests-2.9/bin/activate

    if [ -f ${TEMPEST_REPORT_PATH} ]; then
        python ${FUEL_QA_PATH}fuelweb_test/testrail/report_tempest_results.py -r "${CLUSTER_CONF}" -c "${RELEASE}" -i "${ISO}" -p "${TEMPEST_REPORT_PATH}"
    else
        python ${FUEL_QA_PATH}fuelweb_test/testrail/report_tempest_results.py -r "${CLUSTER_CONF}" -c "${RELEASE}" -i "${ISO}" -p "" -f
    fi
    {
    echo "------------------------------------------------------"
    echo "DONE"
    echo
    }
}
