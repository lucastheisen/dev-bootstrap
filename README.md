# Developer Environment Bootstrapping

Given that windows does not have a native ansible client, this bootstrap uses WSL Ansible.
The `bootstrap.ps1` does _just enough_ to get WSL and Ansible installed an configured before handing off management to Ansible.

## Get Started

To start, you will need to open a powershell console _as Administrator_.
The bootstrap script writes informational messages using `Write-Information`, so you will likely want to set `$InformationPreference = "Continue"`.
Now you will need run this script:

```powershell
Invoke-WebRequest `
    -Uri https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/master/bootstrap.ps1 `
    -UseBasicParsing `
    | Invoke-Expression
```

## Configuration

This bootstrap is configured via the ansible `vars` file: `$env:LOCALAPPDATA\dev-bootstrap\config.yml`.
The configuration is of has a root `roles` variable that is a `dict` whose keys are the names of roles to enable.
The values are configuration for the role itself.

For example:

```yaml
---
roles:
  test:
    var1: foo
    var2: bar
  wsl_docker:
```

Will enable the `test` and `wsl_docker` roles, and provide the `test` role with configuration variables.

### The dev-bootstrap Command

After the first run, a [`dev-bootstrap` bash alias is created](roles/devbootstrap/templates/dev-bootstrap.sh#L8) that provides cli access to bootstrap configuration.
Run `dev-bootstrap --help` for details.

### External Repositories

External ansible repositories can be included as long as they can be `git clone`'d.
They are configured under the `external.repos` key, and are required to provide a `uri` and an optional `ref`.
Additionally, they must include a `roles` section that will be combined with the main `roles`.

For Example:

```yaml
---
external:
  repos:
  - ref: ansible
    roles:
      dotfiles:
    uri: git@github.com:lucastheisen/dotfiles.git
```

When external repositories are configured, they will be fetched/updated before being used.

### Execution Order

By default, all configured roles have the same weight, so execution order will be arbitrary.
When possible, relying or order of exection should be avoided, but in case this is not possible, you can influence order by adding a `role_weight` key to any roles configuration.
This can be any numeric value (decimal included), and will be used to sort roles before applying them.
If not specified, `role_weight` will default to `0`.

For Example, if you need a role to run after all other roles, you can (assuming this is the only explicitly weighted role):

```yaml
---
roles:
  last_role:
    role_weight: 1
```

## Update

As configuration changes, you will need to re-run the bootstrap.  The primary approach to updating is to simply use:

```bash
dev-bootstrap update
```

However, you can also:

### From powershell

Just re-run the same command as [Get Started](#get-started).

### From bash

From a bash shell, run:

```bash
curl https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/master/bootstrap.sh | bash
```

## Development

The simplest feedback loop for development is to check out this code and use `bootstrap.sh` with the `unversioned` branch:

```bash
ANSIBLE_VERBOSITY=6 GIT_BRANCH=unversioned ./bootstrap.sh
```

## Known Issues

### Unable to start service minikube

The minikube self-signed certificate that gets generated upon startup expires, and when it does, you get the following error:

```console
TASK [container_host : Enable minikube systemd service] ***************************************************************************************************************************************************************************************
fatal: [localhost]: FAILED! => {"changed": false, "msg": "Unable to start service minikube: Job for minikube.service failed because the control process exited with error code.\nSee \"systemctl status minikube.service\" and \"journalctl -xeu minikube.service\" for details.\n"}
```

You can confirm the error with:

```bash
journalctl -xeu minikube.service | grep 'the certificate has expired'
```

When this occur's, the simplest fix is to delete the cluster and re-run the bootstrap:

```bash
minikube delete
dev-bootstrap udpate
```

_Note_, this may result in data loss.
