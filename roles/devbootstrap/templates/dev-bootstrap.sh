# Set PATH so it includes user's private bin if it exists
if [ -d "${HOME}/bin" ] ; then
  PATH="${HOME}/bin:${PATH}"
fi

export TERM=xterm-256color

alias dev-bootstrap='python ${DEV_BOOTSTRAP_GIT:-{{ dev_bootstrap.install_dir }}/git/dev-bootstrap}/devbootstrap/devbootstrap.py'

set -o vi
