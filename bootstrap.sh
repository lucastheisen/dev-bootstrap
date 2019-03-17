#!/bin/bash

readonly GIT_REPO_URL="https://github.com/lucastheisen/dev-bootstrap.git"

echo "Install ansible dependencies"
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible

echo "Install/update ansible"
sudo apt-get update
sudo apt-get -y install ansible git python-pip
sudo pip install 'pywinrm>=0.3.0'

$git_dir
if [ ! -d "$git_dir" ]; then
  echo "Cloning dev-bootstrap"
  git clone "${GIT_REPO_URL}" $git_dir
else 
  echo "Pulling latest changes to dev-bootstrap"
  git -C "${git_dir}" pull
  chmod 700 "${git_dir}/run_ansible.sh"
fi

"${git_dir}/run_ansible.sh"
