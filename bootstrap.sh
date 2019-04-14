#!/bin/bash

readonly GIT_REMOTE_URL="${GIT_REMOTE_URL:-https://github.com/lucastheisen/dev-bootstrap.git}"
readonly GIT_BRANCH="${GIT_BRANCH:-master}"
readonly GIT_DIR="$(wslpath "$(powershell.exe -NoProfile Write-Output '$env:LOCALAPPDATA/dev-bootstrap/git' | sed $'s/\r//')")"

if ! grep -rE --include '*.list' '^deb https?://ppa\.launchpad\.net/ansible' /etc/apt/sources.* > /dev/null 2>&1; then
  echo -e "\n\nInstall ansible apt repository"
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  sudo apt-add-repository -y ppa:ansible/ansible
fi

echo -e "\n\nInstall/update ansible"
sudo apt-get update
sudo apt-get -y install ansible git python-pip
sudo pip install 'pywinrm>=0.3.0'

if [ ! -d "$GIT_DIR" ]; then
  echo -e "\n\nCloning into ${GIT_DIR}"
  git clone "${GIT_REMOTE_URL}" $GIT_DIR
else 
  git -C "${GIT_DIR}" remote set-url origin "${GIT_REMOTE_URL}"

  echo -e "\n\nPulling latest changes into ${GIT_DIR}"
  git -C "${GIT_DIR}" pull --force
fi

echo -e "\n\nCheckout branch ${GIT_BRANCH}"
git -C "${GIT_DIR}" checkout "${GIT_BRANCH}" --force

echo -e "\n\nRun ansible"
chmod 700 "${GIT_DIR}/run_ansible.sh"
exec "${GIT_DIR}/run_ansible.sh" "$@"
