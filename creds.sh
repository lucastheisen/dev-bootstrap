#!/bin/bash

set -e

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly POWERSHELL_DIR="${ROOT_DIR}/powershell"
readonly WIN_PATH_CREDS_JSON="~/.developer/test-dev-bootstrap/creds.json"

function encode_command {
  local script_file="${POWERSHELL_DIR}/$1.ps1"
  shift

  local script
  script="$(cat "$script_file")"
  for substitution in "$@"; do
    script=$(sed -e "$substitution" <<< "$script")
  done

  iconv -f UTF-8 -t UTF-16LE <<< "$script" | base64 -w 0
}

function powershell_command {
  if results="$(powershell.exe -NonInteractive -NoProfile -EncodedCommand "$(encode_command "$@")" 2> /dev/null)"; then
    sed 's/\r//g' <<< "$results"
  else
    exit $?
  fi
}

if ! creds=$(powershell_command get_creds); then
  read -s -p "Windows username: " username
  echo
  read -s -p "Windows password: " password
  echo
  creds="$(powershell_command set_creds "s/{{USERNAME}}/$username/" "s/{{PASSWORD}}/$password/")"
fi

echo -e "$creds"
