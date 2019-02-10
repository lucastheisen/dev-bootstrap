# Developer Environment Bootstrapping
Given that windows does not have a native ansible client, this bootstrap uses WSL Ansible.  The `bootstrap.ps1` does _just enough_ to get WSL and Ansible installed an configured before handing off management to Ansible.

## Get Started
To start, you will need to open a powershell console _as Administrator_.  The bootstrap script writes informationaly messages using `Write-Information`, so you will likely want to set `$InformationPreference = "Continue"`.  Now you will need run this script:
```
Invoke-WebRequest `
    -Uri https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/master/bootstrap.ps1 `
    -UseBasicParsing `
    | Invoke-Expression
```
The first time it runs, you will be asked to provide your WSL username.  Each subsequent run will pull that answer from a cache file (`$env:USERPROFILE\.developer\dev-bootstrap\Config.ps1`).

## Configuration
This bootstrap is configured by providing one or more ansible `vars` files in the `$env:USERPROFILE\.developer\dev-bootstrap\vars` directory.  The configuration is based on ansible roles.  The configuration root is a `roles` variable that is a `dict` whose keys are the names of roles to enable.  The values are configuration for the role itself.

For example:
```
---
roles:
  test:
    var1: foo
    var2: bar
  wsl_docker:
```
Will enable the `test` and `wsl_docker` roles, and provide the `test` role with configuration variables.

## Refresh
As configuration changes, you will need to re-run the bootstrap.  You can do so from powershell or bash.

### From powershell
Just re-run the same command as Get Started.

### From bash
From a bash shell, run:
```
curl https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/master/bootstrap.sh |
    bash
```
