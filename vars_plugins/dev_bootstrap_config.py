from ansible.plugins.vars import BaseVarsPlugin
import os
import subprocess

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

        returncode, config_file, err = run_command([
            'wslpath',
            ('%s/dev-bootstrap/config.yml' % (localappdata)),
        ])
        if (returncode):
            self._display.warning("Failed to convert path to WSL: %s" % (err))
            return CACHE['config']

        if 'DEV_BOOTSTRAP_CONFIG' in os.environ:
            with open(config_file, 'wb') as f:
                f.write(os.environ['DEV_BOOTSTRAP_CONFIG'])

        if os.path.exists(config_file):
            CACHE['config'] = loader.load_from_file(config_file, cache=True, unsafe=True)

        return CACHE['config']
