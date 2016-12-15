function vm_clone {
  local src_vm=$1
  local dst_vm=$2

  echo "Cloning $src_vm to $dst_vm"

  virt-clone ${LIBVIRT_SOCKET} -o ${src_vm} -n ${dst_vm} --auto-clone

}

function get_vm_mac {
  local vm_name=$1
  local net_name=$2

  echo $(virsh domiflist ${vm_name} | grep ${net_name} | awk '{print $5}')
}

function get_ip_for_mac {
  local mac="$1"

  ip=$(/usr/sbin/arp -an  |grep "${mac}" | grep -o -P '(?<=\? \().*(?=\) .*)')

  echo ${ip}
}

function execute_ssh_cmd {
  local server=$1
  local ssh_user=$2
  local ssh_pw=$3
  local run_cmd="$4"

  local ssh_opts="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -t -t"
  local ssh_cmd="sshpass -p ${ssh_pw} ssh ${ssh_opts} ${ssh_user}@${server}"

  ${ssh_cmd} "${run_cmd}"

}

function bind_resources {
    local loks_file="$1"
    local env_name="$2"
    local env_ip="$3"

    echo "${env_name}:${env_ip}" >> ${loks_file}
}

function clone_devstack {
  local server="$1"
  local devstack_repo="$2"
  local git_ref="$3"

  execute_ssh_cmd ${server} root r00tme "git clone ${devstack_repo}"

  execute_ssh_cmd ${server} root r00tme  "./devstack/tools/create-stack-user.sh"
  execute_ssh_cmd ${server} root r00tme "echo 'stack:r00tme' |  chpasswd"

  execute_ssh_cmd ${server} stack r00tme  "git clone ${devstack_repo}"

  if [[ -n $git_ref ]]; then
      execute_ssh_cmd ${server} stack r00tme  "cd devstack; git fetch $devstack_repo $git_ref && git checkout FETCH_HEAD"
  fi

}

function clone_bifrost {
  local server="$1"
  local bifrost_repo="$2"
  local git_ref="$3"

  execute_ssh_cmd ${server} root r00tme "mkdir -p /opt/stack/; cd /opt/stack/; git clone ${bifrost_repo}"

  if [[ -n $git_ref ]]; then
      execute_ssh_cmd ${server} root r00tme  "cd /opt/stack/bifrost; git fetch $bifrost_repo $git_ref && git checkout FETCH_HEAD"
  fi

}
