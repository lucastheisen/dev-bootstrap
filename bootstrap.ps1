#Requires -RunAsAdministrator

$gitRepoUrl = "https://github.com/lucastheisen/dev-bootstrap.git"
$dotDeveloper = "$env:USERPROFILE\.developer"
$devBootstrap = "$dotDeveloper\dev-bootstrap"
$devBootstrapConfig = "$devBootstrap\Config.ps1"
$devBootstrapGit = "$devBootstrap\git"
$devBootstrapVars = "$devBootstrap\vars"

function New-Password() {
    param(
        [int] $Length = 10,
        [bool] $Upper = $true,
        [bool] $Lower = $true,
        [bool] $Numeric = $true,
        [string] $Special
    )

    $upperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lowerChars = "abcdefghijklmnopqrstuvwxyz"
    $numericChars = "0123456789"

    $all = ""
    if ($Upper) { $all = "$all$upperChars" }
    if ($Lower) { $all = "$all$lowerChars" }
    if ($Numeric) { $all = "$all$numericChars" }
    if ($Special -and ($special.Length -gt 0)) { $all = "$all$Special" }

    $password = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $password = $password + $all[$(Get-Random -Minimum 0 -Maximum $all.Length)]
    }

    $valid = $true
    if ($Upper -and ($password.IndexOfAny($upperChars.ToCharArray()) -eq -1)) { $valid = $false }
    if ($Lower -and ($password.IndexOfAny($lowerChars.ToCharArray()) -eq -1)) { $valid = $false }
    if ($Numeric -and ($password.IndexOfAny($numericChars.ToCharArray()) -eq -1)) { $valid = $false }
    if ($Special -and $Special.Length -gt 1 -and ($password.IndexOfAny($Special.ToCharArray()) -eq -1)) { $valid = $false }

    if (-not $valid) {
        $password = New-Password `
            -Length $Length `
            -Upper $Upper `
            -Lower $Lower `
            -Numeric $Numeric `
            -Special $Special
    }

    return $password
}

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

if (-not $windowsAnsibleAdministratorSetup) {
    # https://stackoverflow.com/a/51889020/516433
    $winAnsibleUsername = "ansible"
    $winAnsiblePassword = New-Password -Length 30

    # Set-Content writes BOM, so we use this:
    #   https://stackoverflow.com/a/5596984/516433
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines("$devBootstrapVars\admin.yml", `
        "---`nwin_ansible_username: `"$winAnsibleUsername`"`nwin_ansible_password: `"$winAnsiblePassword`"`n", `
        $utf8NoBomEncoding)

    $winAnsiblePasswordSecureString = ConvertTo-SecureString `
        -AsPlainText "$winAnsiblePassword" `
        -Force
    New-LocalUser "$winAnsibleUsername" `
        -Password $winAnsiblePasswordSecureString `
        -FullName "$winAnsibleUsername" `
        -Description "Local ansible admin $winAnsibleUsername" `
        -ErrorAction Stop
    Add-LocalGroupMember `
        -Group "Administrators" `
        -Member "$winAnsibleUsername" `
        -ErrorAction Stop

    "`$windowsAnsibleAdministratorSetup = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $windowsAnsibleSetup) {
    # https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html#winrm-setup
    $file = "$env:temp\ConfigureRemotingForAnsible.ps1"
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1" `
        -UseBasicParsing `
        -OutFile $file `
        | Invoke-Expression

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
