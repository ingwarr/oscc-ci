#!/bin/bash

install_mos_tempest_runner () {
#   Add mos-tempest-runner scripts to fuel master
  if [ -d /tmp/mos-tempest-runner ]; then
    rm -rf /tmp/mos-tempest-runner
  fi
  {
  echo "######################################################"
  echo "Clone mos-tempest-runner from github.com              "
  echo "######################################################"
  }
  cd /tmp/
  git clone https://github.com/Mirantis/mos-tempest-runner.git
  {
  echo "------------------------------------------------------"
  echo "DONE"
  echo
  }
  sync
}


install_package () {
#  if ! $(git version &> /dev/null)
#  then
    yum install -y "$1"
#  fi
}


install_package git
install_package python-virtualenv

install_mos_tempest_runner
