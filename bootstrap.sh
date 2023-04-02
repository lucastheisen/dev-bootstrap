#!/bin/bash

set -e

ROOT_DIR="$(dirname "$(readlink --canonicalize-existing "$0")")"
readonly ROOT_DIR

readonly BOOTSTRAP_DIR="${HOME}/.dev-bootstrap"
# config is on windows dir so that it can be setup before first run
readonly CONFIG_YML="$(wslpath "$(powershell.exe -NoProfile Write-Output '$env:LOCALAPPDATA/dev-bootstrap/config.yml' | sed $'s/\r//')")"

readonly GIT_REMOTE_URL="${GIT_REMOTE_URL:-https://github.com/lucastheisen/dev-bootstrap.git}"
readonly GIT_BRANCH="${GIT_BRANCH:-master}"
readonly GIT_DIR="${BOOTSTRAP_DIR}/git"
readonly VENV_DIR="${BOOTSTRAP_DIR}/venv"

function initialize_ansible {
  if [[ ! -d "${VENV_DIR}" ]]; then
    python3 -m venv "${VENV_DIR}"
  fi

  . "${VENV_DIR}/bin/activate"
  pip install --upgrade pip
  pip install -r "${ROOT_DIR}/requirements.txt"
}

function main {
  local ansible_args=("$@")

  mkdir --parents "${BOOTSTRAP_DIR}"

  sudo dnf install --assumeyes git glibc-langpack-en python3 python3-pip

  initialize_ansible

  local script
  if [[ "${GIT_BRANCH}" == "unversioned" ]]; then
    script="./run_ansible.sh"
  else
    if [[ ! -d "${GIT_DIR}" ]]; then
      echo -e "\n\nCloning into ${GIT_DIR}"
      git clone "${GIT_REMOTE_URL}" "${GIT_DIR}"
    else 
      git -C "${GIT_DIR}" remote set-url origin "${GIT_REMOTE_URL}"
  
      echo -e "\n\nPulling latest changes into ${GIT_DIR}"
      git -C "${GIT_DIR}" pull --force
    fi
  
    echo -e "\n\nCheckout branch ${GIT_BRANCH}"
    git -C "${GIT_DIR}" checkout "${GIT_BRANCH}" --force

    script="${GIT_DIR}/run_ansible.sh"
  fi
  
  local cmd=(bash "${script}" "${ansible_args[@]}")
  echo -e "\n\nRunning $(printf '%q ' "${cmd[@]}" | sed 's/ $//g')"
  exec "${cmd[@]}"
}

main "$@"
