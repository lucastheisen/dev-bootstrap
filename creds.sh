#!/bin/bash

set -e

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly POWERSHELL_DIR="${ROOT_DIR}/vars_plugins/wincreds"
# shellcheck disable=SC2016
readonly WIN_PATH_CREDS_JSON='\$env:LOCALAPPDATA/dev-bootstrap/creds.json'
readonly POWERSHELL='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'

function encode_command {
  local script_file="${POWERSHELL_DIR}/$1.ps1"
  shift

  local script
  script="$(cat "$script_file")"
  for substitution in "$@"; do
    script="$(sed -e "$substitution" <<< "$script")"
  done

  iconv -f UTF-8 -t UTF-16LE <<< "$script" | base64 -w 0
}

function powershell_command {
  if results="$("$POWERSHELL" -NonInteractive -NoProfile -EncodedCommand "$(encode_command "$@")" 2> /dev/null)"; then
    sed 's/\r//g' <<< "$results"
  else
    exit $?
  fi
}

if ! creds="$(powershell_command GetCreds "s'{{CREDS_JSON}}'$WIN_PATH_CREDS_JSON'")"; then
  read -rp "Enter your windows username ($(whoami)): " username
  if [[ -z "$username" ]]; then
    username="$(whoami)"
  fi

  read -rsp "Enter your windows password: " password
  >&2 echo

  powershell_command SetCreds \
    "s'{{CREDS_JSON}}'$WIN_PATH_CREDS_JSON'" \
    "s/{{USERNAME}}/$username/" \
    "s/{{PASSWORD}}/$password/" \
    > /dev/null

  if ! creds="$(powershell_command GetCreds "s'{{CREDS_JSON}}'$WIN_PATH_CREDS_JSON'")"; then
    >&2 echo "Authentication failed"
    exit 1
  fi
fi

echo -e "$creds"
