from ansible.module_utils.basic import AnsibleModule
from ansible.plugins.vars import BaseVarsPlugin
from ansible.template import Templar
from base64 import b64encode
from getpass import getpass, getuser
import json
import os
import subprocess
import sys

WINCREDS = {}
CREDS_JSON = '$env:LOCALAPPDATA/dev-bootstrap/creds.json'
POWERSHELL = 'powershell.exe'

def load_creds(loader):
    get_creds_file = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        'wincreds',
        'GetCreds.ps1')

    with open(get_creds_file) as f: get_creds = f.read()
    templar = Templar(
        loader=loader,
        variables={
            'CREDS_JSON': CREDS_JSON,
        })
    encoded_command = b64encode(templar.template(get_creds).encode('utf-16-le'))

    try:
        with open('/dev/null') as f:
            res = subprocess.check_output(
                [POWERSHELL, '-NonInteractive', '-NoProfile', '-EncodedCommand', encoded_command],
                stdin=sys.stdin,
                stderr=f)
        wincreds = json.loads(res)
        WINCREDS['wincreds'] = {
            'username': wincreds['UserName'],
            'password': wincreds['Password'],
        }
    except subprocess.CalledProcessError:
        save_creds(loader)

def save_creds(loader):
    default_user = getuser()
    user = raw_input('Windows username (%s):' % (default_user)).strip()
    WINCREDS['wincreds'] = {
        'username': user if user else default_user,
        'password': getpass('Windows password:')
    }

    set_creds_file = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        'wincreds',
        'SetCreds.ps1')

    with open(set_creds_file) as f: set_creds = f.read()
    templar = Templar(
        loader=loader,
        variables={
            'CREDS_JSON': CREDS_JSON,
            'USERNAME': WINCREDS['wincreds']['username'],
            'PASSWORD': WINCREDS['wincreds']['password'],
        })
    encoded_command = b64encode(templar.template(set_creds).encode('utf-16-le'))

    try:
        with open('/dev/null') as f:
            subprocess.check_output(
                [POWERSHELL, '-NonInteractive', '-NoProfile', '-EncodedCommand', encoded_command],
                stdin=sys.stdin,
                stderr=f)
    except subprocess.CalledProcessError:
        pass


class VarsModule(BaseVarsPlugin):
    def get_vars(self, loader, path, entities, cache=True):
        super(VarsModule, self).get_vars(loader, path, entities)

        if 'wincreds' not in WINCREDS:
            load_creds(loader)

        return WINCREDS
