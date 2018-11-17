#!/bin/bash

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
ansible-playbook update.yml $@
