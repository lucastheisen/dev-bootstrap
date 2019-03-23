#!/bin/bash

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ANSIBLE_CONFIG=./ansible.cfg ansible-playbook update.yml "$@"
