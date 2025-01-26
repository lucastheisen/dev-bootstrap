from ansible.errors import AnsibleParserError
from ansible.module_utils.basic import AnsibleModule
from ansible.plugins.inventory import BaseInventoryPlugin
from ansible.template import Templar
from base64 import b64encode
from getpass import getpass, getuser
import json
import os
import subprocess
import sys

try:
    from __main__ import display
except ImportError:
    from ansible.utils.display import Display
    display = Display()

LOCALWINRM = {}
WSL_INTERFACE_ALIAS = 'vEthernet (WSL (Hyper-V firewall))'
CREDS_JSON = '$env:LOCALAPPDATA/dev-bootstrap/creds.json'
POWERSHELL = 'powershell.exe'

def load_creds(loader):
    display.vvv("localwinrm read from powershell")
    get_creds_file = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        'localwinrm',
        'GetCreds.ps1')

    try:
        display.vvvvv(f"localwinrm get_creds_file read {get_creds_file}")
        with open(get_creds_file) as f:
            get_creds = f.read()
    except Exception as e:
        raise AnsibleParserError(f'read {get_creds_file} failed', e)

    templar = Templar(
        loader=loader,
        variables={
            'CREDS_JSON': CREDS_JSON,
        })
    encoded_command = b64encode(templar.template(get_creds).encode('utf-16-le'))

    try:
        display.vvvvv("localwinrm execute powershell")
        with open('/dev/null') as f:
            res = subprocess.check_output(
                [POWERSHELL, '-NonInteractive', '-NoProfile', '-EncodedCommand', encoded_command],
                stdin=sys.stdin,
                stderr=f)
        localwinrm = json.loads(res)
        LOCALWINRM['localwinrm'] = {
            'username': localwinrm['UserName'],
            'password': localwinrm['Password'],
        }
        display.vvvvvv("localwinrm user is " + localwinrm['UserName'])
    except subprocess.CalledProcessError:
        display.vvv("localwinrm load failed, try save")
        save_creds(loader)

def save_creds(loader):
    default_user = getuser()
    display.vvv("localwinrm request creds from user")
    user = input('Windows username (%s):' % (default_user)).strip()
    LOCALWINRM['localwinrm'] = {
        'username': user if user else default_user,
        'password': getpass('Windows password:')
    }

    set_creds_file = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        'localwinrm',
        'SetCreds.ps1')

    with open(set_creds_file) as f:
        set_creds = f.read()
    templar = Templar(
        loader=loader,
        variables={
            'CREDS_JSON': CREDS_JSON,
            'USERNAME': LOCALWINRM['localwinrm']['username'],
            'PASSWORD': LOCALWINRM['localwinrm']['password'],
        })
    encoded_command = b64encode(templar.template(set_creds).encode('utf-16-le'))

    try:
        display.vvvvv("localwinrm execute powershell for saving creds")
        with open('/dev/null') as f:
            subprocess.check_output(
                [POWERSHELL, '-NonInteractive', '-NoProfile', '-EncodedCommand', encoded_command],
                stdin=sys.stdin,
                stderr=f)
    except subprocess.CalledProcessError:
        pass

def wsl_ip():
    display.vvv("localwinrm detect WSL ip")
    encoded_command = b64encode(
        f'(Get-NetIPAddress -InterfaceAlias "{WSL_INTERFACE_ALIAS}" -AddressFamily "IPv4").IPAddress'.encode('utf-16-le'))

    try:
        with open('/dev/null') as f:
            LOCALWINRM['wsl_ip'] = subprocess.check_output(
                [POWERSHELL, '-NonInteractive', '-NoProfile', '-EncodedCommand', encoded_command],
                stdin=sys.stdin,
                stderr=f).rstrip().decode('utf-8')
    except Exception as e:
        raise AnsibleParserError(f'win ip detection failed', e)

class InventoryModule(BaseInventoryPlugin):
    NAME = "localwinrm"

    def parse(self, inventory, loader, path, cache=True):
        super(InventoryModule, self).parse(inventory, loader, path, cache)

        name = 'localwinrm'
        display.vvv('localwinrm inventory starting')
        if 'localwinrm' not in LOCALWINRM:
            display.vvv('localwinrm inventory loading')
            self.inventory.add_host(name)
            self.inventory.set_variable(name, 'ansible_connection', 'winrm')
            self.inventory.set_variable(name, 'ansible_winrm_transport', 'credssp')
            self.inventory.set_variable(name, 'ansible_winrm_server_cert_validation', 'ignore')
            try:
                wsl_ip()
                self.inventory.set_variable(name, 'ansible_host', LOCALWINRM['wsl_ip'])

                load_creds(loader)
                self.inventory.set_variable(name, 'localwinrm', LOCALWINRM['localwinrm'])
                self.inventory.set_variable(name, 'ansible_user', LOCALWINRM['localwinrm']['username'])
                self.inventory.set_variable(name, 'ansible_password', LOCALWINRM['localwinrm']['password'])
            except AnsibleParserError as e:
                display.vvv(f'localwinrm inventory loading failed: {e}')
                raise
            except Exception as e:
                display.vvv(f'localwinrm inventory loading failed: {e}')
                raise AnsibleParserError('load creds failed', e)

    def verify_file(self, path):
        display.v('localwinrm verify_file')
        return True
