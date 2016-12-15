#!/bin/bash

apt -y update && apt -y upgrade
cd /opt/stack/bifrost
bash ./scripts/env-setup.sh
source /opt/stack/bifrost/env-vars
source /opt/stack/ansible/hacking/env-setup
cd playbooks; ansible-playbook -v -i inventory/localhost install.yaml
cd /opt/stack/
git clone git://git.openstack.org/openstack/ironic-staging-drivers
cd ironic-staging-drivers/
pip install -e .
pip install "ansible<2.2"
sed -i '/enabled_drivers =*/c\enabled_drivers = fake_ansible,pxe_ipmitool_ansible,pxe_ssh_ansible,pxe_libvirt_ansible' /etc/ironic/ironic.conf
service ironic-conductor restart
echo "export BIFROST_INVENTORY_SOURCE=/opt/stack/bifrost/playbooks/inventory/baremetal.yml
source /opt/stack/bifrost/env-vars
source /opt/stack/ansible/hacking/env-setup" >> /root/.bashrc
