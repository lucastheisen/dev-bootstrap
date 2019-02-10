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

if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne "enabled") {
    Write-Debug "Enabling WSL"
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    Write-Information "Restart required.  Please restart, then run this script again"
    exit
}

if (-not ((Get-AppxPackage -Name CanonicalGroupLimited.Ubuntu18.04onWindows).Status -eq "ok")) {
    $ProgressPreference = "SilentlyContinue"
    $ubuntuAppx = "$env:USERPROFILE\Downloads\ubuntu.appx"
    Write-Information "Downloading ubuntu... This may take a while."
    Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile $ubuntuAppx -UseBasicParsing

    Write-Information "Installing ubuntu application"
    Add-AppxPackage -Path $ubuntuAppx

    Write-Information "Installing ubuntu application"
    ubuntu1804.exe install --root
}

New-Item -Path $devBootstrapVars -ItemType Directory -Force | Out-Null
if (-not (Test-Path -Path $devBootstrapVars -PathType Container)) {
    Write-Error "$devBootstrapVars is not a directory" -ErrorAction Stop
}

if (Test-Path -Path $devBootstrapConfig) {
    . $devBootstrapConfig
}
else {
    $wslUsername = Read-Host -Prompt 'What is your WSL username (will be created if it does not exist)?'
    "`$wslUsername = `"$wslUsername`"" | Out-File $devBootstrapConfig -Append
}
$wslDotDeveloper = "/home/$wslUsername/.developer";

Write-Information "wslUsername [$wslUsername]"
Write-Information "in passwd   [$(ubuntu1804.exe run "cat /etc/passwd | grep $wslUsername")]"
if (-not ((ubuntu1804.exe run "cat /etc/passwd | grep $wslUsername") -match "^$wslUsername`:")) {
    Write-Information "$wslUsername does not exist...  Creating"
    ubuntu1804.exe run "adduser $wslUsername"
}

Write-Information "Setting ubuntu default user to $wslUsername"
ubuntu1804.exe config --default-user "$wslUsername"

if (-not $sudoersConfigured) {
    Write-Information "Add sudo ALL for $wslUsername"
    ubuntu1804.exe config --default-user root
    
    ubuntu1804.exe run "echo '$wslUsername ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$wslUsername"
    ubuntu1804.exe run "chmod 0440 /etc/sudoers.d/$wslUsername"
    
    ubuntu1804.exe config --default-user $wslUsername
    "`$sudoersConfigured = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $dependenciesInstalled) {
    Write-Information "Installing ansible dependencies"
    ubuntu1804.exe run sudo apt-get update
    ubuntu1804.exe run sudo apt-get install -y software-properties-common
    ubuntu1804.exe run sudo apt-add-repository -y ppa:ansible/ansible
    
    Write-Information "Installing ansible"
    ubuntu1804.exe run sudo apt-get update
    ubuntu1804.exe run sudo apt-get -y install ansible git
    "`$dependenciesInstalled = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $dotDeveloperLinked) {
    Write-Information "Linking ~/.developer"
    ubuntu1804.exe run "[ ! -e $wslDotDeveloper ] && ln -s `$(wslpath '$dotDeveloper') $wslDotDeveloper"
    "`$dotDeveloperLinked = `$true" | Out-File $devBootstrapConfig -Append
}

if (-not $windowsAnsibleAdministratorSetup) {
    Write-Information "Creating ansible windows administrative user"
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
    Write-Information "Configuring windows for ansible"
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
    Write-Information "Cloning dev-bootstrap"
    ubuntu1804.exe run "git clone $gitRepoUrl $wslDotDeveloper/dev-bootstrap/git"
}

Write-Information "Pulling latest changes to dev-bootstrap"
ubuntu1804.exe run "git -C $wslDotDeveloper/dev-bootstrap/git pull"
ubuntu1804.exe run "chmod 700 $wslDotDeveloper/dev-bootstrap/git/run_ansible.sh"

Write-Information "Running dev-bootstrap ansible playbook"
ubuntu1804.exe run "$wslDotDeveloper/dev-bootstrap/git/run_ansible.sh"
