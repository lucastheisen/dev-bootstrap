import codecs
import os
import shlex
import subprocess
import tempfile
import yaml

def _config_file():
    returncode, localappdata, err = _run_command([
        'powershell.exe',
        '-NoProfile',
        'Write-Output',
        '$env:LOCALAPPDATA',
    ])
    if (returncode):
        raise Exception("Failed to resolve config file: %s" % (err))

    returncode, config_file, err = _run_command([
        'wslpath',
        ('%s/dev-bootstrap/config.yml' % (localappdata)),
    ])
    if (returncode):
        raise Exception("Failed to convert path to WSL: %s" % (err))

    return config_file

def _dump(config):
    return yaml.dump(config, default_flow_style=False, indent=2)

def edit(args):
    # inspired by ansible vault edit:
    #   https://github.com/ansible/ansible/blob/5c992fcc3f911d52c9c5512c178bc27e0236e30f/lib/ansible/parsing/vault/__init__.py#L845-L880
    config_file = _config_file()

    config = _load(config_file)
    try:
        (file_handle, temp_file) = tempfile.mkstemp()
        os.close(file_handle)

        _save(config, temp_file)

        env_editor = os.environ.get('EDITOR', 'vi')
        command = shlex.split(env_editor)
        command.append(temp_file)
        subprocess.call(command)

        config = _load(temp_file)
        _save(config, config_file)
    finally:
        if os.path.exists(temp_file):
            os.remove(temp_file)

def _load(file):
    with open(file, 'r') as f:
        return yaml.load(f.read())

def _run_command(args):
    proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()
    return proc.returncode, (out.rstrip() if out else None), (err.rstrip() if out else None)

def set_value(args):
    config_file = _config_file()
    full_config = _load(config_file)
    name_parts = args.name.split('.')

    config = full_config
    for branch_name in name_parts[:-1]:
        if branch_name in config:
            config = config[branch_name]
        else:
            config[branch_name] = {}

    value = yaml.load(args.value)
    if value is None:
        del(config[name_parts[-1]])
    else:
        config[name_parts[-1]] = value

    _save(config, config_file)

def _save(config, file):
    with codecs.open(file, 'w', 'utf-8') as f:
        f.write(_dump(config))

def view(args):
    print(_dump(_load(_config_file())))
