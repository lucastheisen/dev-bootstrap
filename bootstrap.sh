#!/bin/bash

GIT_DIR="$HOME/.developer/dev-bootstrap/git"
git -C $GIT_DIR pull
$GIT_DIR/run_ansible.sh
