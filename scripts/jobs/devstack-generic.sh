set -ex

HELPERS_DIR=$(dirname "$0")/../

ENV_NAME=${BUILD_USER_ID}-${DEP_NAME}

LIBVIRT_SOCKET="--connect=qemu:///system"
LOCK_FILE='/home/jenkins/loks/devstack-generic.lock'

source /etc/profile.d/devstack-generic.sh
# DEVSTACK_NET_PREFIX
# DEVSTACK_NET_NAME

#Devstack
DEVSTACK_REPO=${DEVSTACK_REPO:-'git://git.openstack.org/openstack-dev/devstack'}

export LC_ALL=C

echo $ENV_NAME |grep -q "_" && (echo "Can't use char "_" in the hostname"; exit 1)
[ -z "$LOCAL_CONF" ] && (echo "LOCAL_CONF can't be empty"; exit 1)

DISTRO_RELEASE=${DISTRO_RELEASE:-ubuntu-trusty}

if [[ "$DISTRO_RELEASE" == "ubuntu-trusty" ]]; then
    SRC_VM='devstack-generic'
else
    SRC_VM="devstack-generic-$DISTRO_RELEASE"
fi

source $HELPERS_DIR/helpers.sh
source $HELPERS_DIR/devstack-helpers.sh


function main {

  vm_clone ${SRC_VM} ${ENV_NAME}
  local vm_mac=$(get_vm_mac $ENV_NAME $DEVSTACK_NET_NAME)

  virsh start ${ENV_NAME}
  sleep 120 #

  local env_ip=$(get_ip_for_mac "$vm_mac")

  #Change hostname
  execute_ssh_cmd ${env_ip} root r00tme "echo $ENV_NAME > /etc/hostname; \
  sed -i "s/devstack-generic/$ENV_NAME/g" /etc/hosts; \
  hostname $ENV_NAME; (sleep 1; reboot) &"

  sleep 15

  waitForSSH "${env_ip}"

  bind_resources $LOCK_FILE $ENV_NAME $env_ip

  clone_devstack ${env_ip} $DEVSTACK_REPO ${DEVSTACK_BRANCH}

  # Copy local.conf to devstack
  echo "$LOCAL_CONF"  > /tmp/${ENV_NAME}-local.conf
  local scp_opts='-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no'
  sshpass -p 'r00tme'  scp $scp_opts  /tmp/${ENV_NAME}-local.conf stack@${env_ip}://opt/stack/devstack/local.conf
  rm -f /tmp/${ENV_NAME}-local.conf

  execute_ssh_cmd ${env_ip} stack r00tme  "cd ~/devstack; ./stack.sh; exit"

  echo "Done"

}

main
