#!/bin/bash -e

#    Copyright 2014 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

#Environment variables
# FUEL_IP=""
# SSH_USER_NAME=""
# SSH_USER_PASS=""
# TESTS_TO_RUN=""
# KEEP_ENV=""


source /home/jenkins/oscc-ci/scripts/helpers.sh

INSTALL_MOS_TEMPEST_RUNNER_LOG=${INSTALL_MOS_TEMPEST_RUNNER_LOG:-"install_mos_tempest_runner_log.txt"}
RUN_TEMPEST_LOG=${RUN_TEMPEST_LOG:-"run_tempest_log.txt"}
RUN_TEMPEST_LOG_PATH=${RUN_TEMPEST_LOG_PATH:-"."}


SSH_USER_NAME="root"
SSH_USER_PASS="r00tme"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

RES=0

ssh_to_master() {
    SSH_CMD="sshpass -p ${SSH_USER_PASS} ssh ${SSH_OPTIONS} ${SSH_USER_NAME}@${FUEL_IP}"
    ${SSH_CMD} "$1"
}

scp_from_fuel_master() {
    SCP_CMD="sshpass -p ${SSH_USER_PASS} scp ${SSH_OPTIONS}"
    case $1 in
        -r|--recursive)
        SCP_CMD+=" -r "
        shift
        ;;
    esac
    ${SCP_CMD} ${SSH_USER_NAME}@${FUEL_IP}:$@
}

scp_to_fuel_master() {
    SCP_CMD="sshpass -p ${SSH_USER_PASS} scp ${SSH_OPTIONS}"
    case $1 in
        -r|--recursive)
        SCP_CMD+=" -r "
        shift
        ;;
    esac
    ${SCP_CMD} ${1} ${SSH_USER_NAME}@${FUEL_IP}:${2}
}


check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]
        then
        if [ -n "$2" ]; then
            echo "$2"
        fi
        RES=1
    fi
}


run_tempest() {
    project_name=$1
    {
    echo "######################################################"
    echo "Install mos-tempest-runner project                    "
    echo "######################################################"
    } | tee -a ${LOG}
    scp_to_fuel_master /home/jenkins/oscc-ci/scripts/install-mos-tempest-runner.sh /tmp/
    ssh_to_master /tmp/install-mos-tempest-runner.sh | tee -a ${INSTALL_MOS_TEMPEST_RUNNER_LOG}
    set +e
    ssh_to_master "/tmp/mos-tempest-runner/setup_env.sh" | tee -a ${INSTALL_MOS_TEMPEST_RUNNER_LOG}
    set -e
    check_return_code_after_command_execution $? "Install mos-tempest-runner is failure. Please see ${INSTALL_MOS_TEMPEST_RUNNER_LOG}"
    {
    echo "######################################################"
    echo "Run tempest tests                                     "
    echo "######################################################"
    } | tee -a ${LOG}
    set +e
    ( ssh_to_master <<EOF; echo $? ) | tee ${RUN_TEMPEST_LOG}
/tmp/mos-tempest-runner/rejoin.sh
. /home/developer/mos-tempest-runner/.venv/bin/activate
. /home/developer/openrc
run_tests tempest.api."${project_name}"
EOF

    scp_from_fuel_master -r /home/developer/mos-tempest-runner/tempest-reports/ ${RUN_TEMPEST_LOG_PATH}
    set -e
    return_code=$(tail -1  ${RUN_TEMPEST_LOG})
    check_return_code_after_command_execution ${return_code} "Run tempest tests for ${project_name} is failure."
}

if [[ -z ${TESTS_TO_RUN} ]]
then
  run_tempest
else
  for i in ${TESTS_TO_RUN}
  do
    run_tempest ${i}
    if [[ ${EXPORT_TO_TESTRAIL} == 'true' ]]; then
      testrail_results "${FUEL_IP}" "${WORKSPACE}/tempest-reports/tempest-report.xml"
    fi
  done
fi

exit ${RES}
