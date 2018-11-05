$gitRepoUrl = "https://github.com/lucastheisen/dev-bootstrap.git"
$dotDeveloper = "$env:USERPROFILE\.developer"
$devBootstrap = "$dotDeveloper\dev-bootstrap"
$devBootstrapConfig = "$devBootstrap\Config.ps1"
$devBootstrapGit = "$devBootstrap\git"
$devBootstrapVars = "$devBootstrap\vars"

New-Item -Path $devBootstrapVars -ItemType Directory -Force | Out-Null
if (-not (Test-Path -Path $devBootstrapVars -PathType Container)) {
    Write-Error "$devBootstrapVars is not a directory" -ErrorAction Stop
}

if (Test-Path -Path $devBootstrapConfig) {
    . $devBootstrapConfig
}
else {
    $wslUsername = Read-Host -Prompt 'What is your WSL username?'
    "`$wslUsername = `"$wslUsername`"" | Out-File $devBootstrapConfig -Append
}
$wslDotDeveloper = "/home/$wslUsername/.developer";

if (-not $sudoersConfigured) {
    ubuntu1804.exe config --default-user root
    
    ubuntu1804.exe run "echo '$wslUsername ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$wslUsername"
    ubuntu1804.exe run "chmod 0440 /etc/sudoers.d/$wslUsername"
    
    ubuntu1804.exe config --default-user $wslUsername
    "`$sudoersConfigured = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $dependenciesInstalled) {
    ubuntu1804.exe run sudo apt-get update
    ubuntu1804.exe run sudo apt-get install -y software-properties-common
    ubuntu1804.exe run sudo apt-add-repository -y ppa:ansible/ansible
    
    ubuntu1804.exe run sudo apt-get update
    ubuntu1804.exe run sudo apt-get -y install ansible git
    "`$dependenciesInstalled = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $dotDeveloperLinked) {
    ubuntu1804.exe run "[ ! -e $wslDotDeveloper ] && ln -s `$(wslpath '$dotDeveloper') $wslDotDeveloper"
    "`$dotDeveloperLinked = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $windowsAnsibleSetup) {
    # https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html#winrm-setup
    $file = "$env:temp\ConfigureRemotingForAnsible.ps1"
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1" `
        -UseBasicParsing `
        -OutFile $file
    Start-Process powershell.exe -Verb runas -ArgumentList "-ExecutionPolicy bypass -File $file" -ErrorAction Stop

    ubuntu1804.exe run sudo apt-get update
    ubuntu1804.exe run sudo apt-get -y install python-pip
    ubuntu1804.exe run pip install "pywinrm>=0.3.0"

    "`$windowsAnsibleSetup = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not (Test-Path -Path $devBootstrapGit)) {
    ubuntu1804.exe run "git clone $gitRepoUrl $wslDotDeveloper/dev-bootstrap/git"
}

ubuntu1804.exe run "git -C $wslDotDeveloper/dev-bootstrap/git pull"
ubuntu1804.exe run "$wslDotDeveloper/dev-bootstrap/git/run_ansible.sh"
