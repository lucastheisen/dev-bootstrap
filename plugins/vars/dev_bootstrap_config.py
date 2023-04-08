from ansible.plugins.vars import BaseVarsPlugin
from ansible.module_utils._text import to_text
import os
import subprocess

try:
    from __main__ import display
except ImportError:
    from ansible.utils.display import Display
    display = Display()

CACHE = {}

# ansible has a run_command in module_utils/basic.py, but is part of the
# AnsibleModule class, we need a function that is similar in nature but
# available outside of that class
def run_command(args):
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (out, err) = proc.communicate()
        return proc.returncode, (to_text(out.rstrip()) if out else None), (to_text(err.rstrip()) if out else None)

class VarsModule(BaseVarsPlugin):
    def get_vars(self, loader, path, entities, cache=True):
        super(VarsModule, self).get_vars(loader, path, entities)

        if ('config' in CACHE):
            return CACHE['config']

        CACHE['config'] = {}

        config_file = os.path.join(os.environ['HOME'], '.config', 'dev-bootstrap', 'config.yml')
        install_dir = os.path.join(os.environ['HOME'], '.local', 'share', 'dev-bootstrap')
        CACHE['config'] = dict(
            dev_bootstrap = dict(
                config_file = config_file,
                lib_dir = os.path.join(install_dir, 'lib'),
                install_dir = install_dir,
                venv_dir = os.path.join(install_dir, 'venv'),
            ),
        )

        if os.path.exists(config_file):
            display.vvvv('Found %s' % (config_file))
            CACHE['config'].update(loader.load_from_file(config_file, cache=True, unsafe=False))
        else:
            default_config = 'roles:\n  devbootstrap:'
            display.vvvv('Writing default %s\n%s' % (config_file, default_config))
            with open(config_file, 'wb') as f:
                f.write(default_config)
            CACHE['config'].update(loader.load_from_file(config_file, cache=True, unsafe=False))

        return CACHE['config']
