#!/bin/bash

set -e

ROOT_DIR="$(dirname "$(readlink --canonicalize-existing "$0")")"
readonly ROOT_DIR

readonly ANSIBLE_CONFIG=./ansible.cfg
readonly BOOTSTRAP_DIR="${HOME}/.local/share/dev-bootstrap"

readonly GIT_BRANCH="${GIT_BRANCH:-master}"
readonly GIT_REMOTE_URL="${GIT_REMOTE_URL:-https://github.com/lucastheisen/dev-bootstrap.git}"
readonly LIB_DIR="${BOOTSTRAP_DIR}/lib"
readonly VENV_DIR="${BOOTSTRAP_DIR}/venv"

function initialize_ansible {
  if [[ ! -d "${VENV_DIR}" ]]; then
    log v "creating ansible venv"
    python3 -m venv "${VENV_DIR}"
  fi

  . "${VENV_DIR}/bin/activate"
  log v "installing python dependencies:\n$(sed 's/^/  /' "${LIB_DIR}/requirements.txt")"
  pip install --upgrade pip
  pip install -r "${LIB_DIR}/requirements.txt"

  log v "installing galaxy collections:\n$(sed 's/^/  /' "${LIB_DIR}/requirements.yml")"
  ansible-galaxy collection install --requirements-file "${LIB_DIR}/requirements.yml"
}

function log {
  local verbosity=$1
  local message=$2
 
  if [[ "${LOG_VERBOSITY:-v}" =~ ^${verbosity} ]]; then
    >&2 printf "%s [%3s] %s: %b\n" \
      "$(date +%H:%M:%S)" \
      "${verbosity}" \
      "$(caller 0 | awk '{print $2}')" \
      "${message}"
  fi
}

function run_ansible {
  local dir=$1

  local cmd=(ansible-playbook update.yml "${ansible_args[@]}")
  pushd "${dir}" > /dev/null
  log v "running: $(printf '%q ' "${cmd[@]}" | sed 's/ $//g')"
  export ANSIBLE_CONFIG
  "${cmd[@]}"
  popd > /dev/null
}

function main {
  local ansible_args=("$@")

  mkdir --parents "${BOOTSTRAP_DIR}"

  log v "installing bootstrap dependencies"
  # these are the dependencies for ansible itself and any galaxy modules
  # used by ansible. all other packages should be installed by roles
  sudo dnf install --assumeyes \
    git \
    glibc-langpack-en \
    procps-ng \
    python3 \
    python3-pip

  initialize_ansible

  if [[ "${GIT_BRANCH}" == "unversioned" ]]; then
    if [[ "${ROOT_DIR}" != "${LIB_DIR}" ]]; then
      rm --recursive --force "${LIB_DIR}"
      mkdir --parents "${LIB_DIR}"
      tar --create --directory "${ROOT_DIR}" . | tar --extract --directory "${LIB_DIR}"
    fi
    run_ansible "${LIB_DIR}"
  else
    log v "fetch dev-bootstrap at ${GIT_BRANCH}"
    rm --recursive --force "${LIB_DIR}"
    mkdir --parents "${LIB_DIR}"
    curl \
      --location \
      "https://github.com/lucastheisen/dev-bootstrap/archive/${GIT_BRANCH}.tar.gz" \
      | tar --extract --gunzip --directory "${LIB_DIR}" --strip-components 1

    run_ansible "${LIB_DIR}"
  fi
}

main "$@"
