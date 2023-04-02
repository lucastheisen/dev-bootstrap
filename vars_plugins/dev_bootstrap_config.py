from ansible.plugins.vars import BaseVarsPlugin
import os
import subprocess

try:
    from __main__ import display
except ImportError:
    from ansible.utils.display import Display
    display = Display()

CACHE = {}

def run_command(args):
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        (out, err) = proc.communicate()
        return proc.returncode, (out.rstrip() if out else None), (err.rstrip() if out else None)

class VarsModule(BaseVarsPlugin):
    def get_vars(self, loader, path, entities, cache=True):
        super(VarsModule, self).get_vars(loader, path, entities)

        if ('config' in CACHE):
            return CACHE['config']

        CACHE['config'] = {}

        returncode, localappdata, err = run_command([
            'powershell.exe',
            '-NoProfile',
            'Write-Output',
            '$env:LOCALAPPDATA',
        ])
        if (returncode):
            self._display.warning("Failed to resolve config file: %s" % (err))
            return CACHE['config']

        returncode, dev_bootstrap_install_dir, err = run_command([
            'wslpath',
            ('%s/dev-bootstrap' % (localappdata)),
        ])
        if (returncode):
            self._display.warning("Failed to convert path to WSL: %s" % (err))
            return CACHE['config']

        config_file = os.path.join(dev_bootstrap_install_dir, b'config.yml')
        CACHE['config'] = dict(
            dev_bootstrap=dict(
                install_dir=dev_bootstrap_install_dir,
                config_file=config_file,
            ),
        )

        if 'DEV_BOOTSTRAP_CONFIG' in os.environ:
            display.vvvv('Writing %s from env var DEV_BOOTSTRAP_CONFIG\n%s' % (config_file, os.environ['DEV_BOOTSTRAP_CONFIG']))
            with open(config_file, 'wb') as f:
                f.write(os.environ['DEV_BOOTSTRAP_CONFIG'])

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
