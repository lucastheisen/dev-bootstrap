#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

git -C $HOME/.developer/dev-bootstrap/git pull
$DIR/run_ansible.sh
