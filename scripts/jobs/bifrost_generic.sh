#!/bin/bash
set -ex

HELPERS_DIR=$(dirname "$0")/../

ENV_NAME=${BUILD_USER_ID}-${DEP_NAME}

LIBVIRT_SOCKET="--connect=qemu:///system"
LOCK_FILE='/home/jenkins/loks/bifrost-generic.lock'

source /etc/profile.d/devstack-generic.sh
# DEVSTACK_NET_PREFIX
# DEVSTACK_NET_NAME

#Bifrost
BIFROST_REPO=${BIFROST_REPO:-'git://git.openstack.org/openstack/bifrost'}
STAGING_DRIVERS_REPO=${STAGING_DRIVERS_REPO:-'git://git.openstack.org/openstack/ironic-staging-drivers'}
export LC_ALL=C

echo $ENV_NAME |grep -q "_" && (echo "Can't use char "_" in the hostname"; exit 1)
#[ -z "$LOCAL_CONF" ] && (echo "LOCAL_CONF can't be empty"; exit 1)

DISTRO_RELEASE=${DISTRO_RELEASE:-ubuntu-xenial}

if [[ "$DISTRO_RELEASE" == "ubuntu-xenial" ]]; then
    SRC_VM='generic_bifrost '
else
    SRC_VM="generic_bifrost-$DISTRO_RELEASE"
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
  sed -i "s/ub16-standard/$ENV_NAME/g" /etc/hosts; \
  hostname $ENV_NAME; (sleep 1; reboot) &"

  sleep 15

  waitForSSH "${env_ip}"

  bind_resources $LOCK_FILE $ENV_NAME $env_ip

  clone_bifrost ${env_ip} $BIFROST_REPO ${BIFROST_BRANCH}
  local scp_opts='-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no'
    if [ -z ${hw_enabled} ] 
     then
         PROV_NET="192.168.10"
         DNSMASQ_ROUTER="192.168.10.2"
         LIBVIRTD_ENABLED=0
         NET_IF="eth1"
     else
         PROV_NET="192.168.122"
	 DNSMASQ_ROUTER="192.168.122.1"
         LIBVIRTD_ENABLED=1
         NET_IF="virbr0"
         execute_ssh_cmd ${env_ip} root r00tme "apt -y install qemu-kvm libvirt-bin virtinst; exit"
	 sshpass -p 'r00tme' scp -r ${scp_opts} $HELPERS_DIR/vm/ root@${env_ip}:/opt/stack/
	 execute_ssh_cmd ${env_ip} root r00tme "cp /opt/stack/vm/ps_bm.xml /etc/libvirt/qemu/ps_bm.xml; cp /opt/stack/pseudo_bm.qcow2 /var/lib/libvirt/images/"
	 execute_ssh_cmd ${env_ip} root r00tme "virsh define /etc/libvirt/qemu/ps_bm.xml && for ((i=1; i<=3; i++)); do virt-clone -o ps_bm -n ps_bm-$i --auto-clone; done "
  fi
mkdir -p /tmp/${ENV_NAME}/
  echo "---
ironic_url: "http://localhost:6385/"
network_interface: ${NET_IF}
ironic_db_password: aSecretPassword473z
mysql_username: root
mysql_password: secret
ssh_public_key_path: "/root/.ssh/id_rsa.pub"
deploy_image_filename: "user_image.qcow2"
create_image_via_dib: false
transform_boot_image: false
create_ipa_image: false
dnsmasq_dns_servers: 8.8.8.8,8.8.4.4
dnsmasq_router: ${DNSMASQ_ROUTER}
dhcp_pool_start: ${PROV_NET}.20
dhcp_pool_end: ${PROV_NET}.50
dhcp_lease_time: 12h
dhcp_static_mask: 255.255.255.0" > /tmp/${ENV_NAME}/localhost

  sshpass -p 'r00tme'  scp ${scp_opts} /tmp/${ENV_NAME}/localhost root@${env_ip}:/opt/stack/bifrost/playbooks/inventory/group_vars/localhost
  rm -f /tmp/${ENV_NAME}/localhost

  sshpass -p 'r00tme' scp ${scp_opts} $HELPERS_DIR/bifrost_install.sh root@${env_ip}:/opt/stack/bifrost_install.sh

  execute_ssh_cmd ${env_ip} root r00tme  "/opt/stack/bifrost_install.sh; export netw="${PROV_NET}"; sed -i "/dhcp-option=3,*/c\dhcp-option=3,${netw}.1" /etc/dnsmasq.conf; service dnsmasq restart; exit"

  echo "Done"

}

main
