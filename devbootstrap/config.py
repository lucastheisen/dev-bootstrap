import codecs
import os
import shlex
import subprocess
import tempfile
import yaml

"""
Manages devbootstrap configuration.
"""

def _config_file():
    if os.name == 'nt':
        config_file = os.path.join(os.environ['LOCALAPPDATA'], 'dev-bootstrap', 'config.yml')
    else: 
        config_file = os.path.join(os.environ['HOME'], '.config', 'dev-bootstrap', 'config.yml')

    return config_file

def _default_editor():
    if os.name == 'nt':
        return 'code.cmd -w'
    else: 
        return 'vi'

def edit(args):
    """
    Opens the config file in an editor.  Will check $EDITOR first, and if not
    specified fall back to `code.cmd -w` for windows, `vi` otherwise.
    """
    env_editor = os.environ.get('EDITOR', _default_editor())
    command = shlex.split(env_editor)
    command.append(_config_file())
    subprocess.call(command)

def view(args):
    """
    Prints out the config file.
    """
    with open(_config_file(), 'r') as f:
        print(f.read())
