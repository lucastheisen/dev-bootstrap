#!/bin/bash

set -e

sudo apt-get update
sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible

sudo apt-get update
sudo apt-get -y install ansible

# Create .developer/dev-bootstrap/vars to use for ansible override
WIN_HOME=$(wslpath $(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null))
DOT_DEVELOPER="$WIN_HOME/.developer"
mkdir -p "$DOT_DEVELOPER/dev-bootstrap/vars"
if [ -e "$DOT_DEVELOPER" ]; then
  ln -s "$DOT_DEVELOPER" ~/.developer
fi

