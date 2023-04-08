#Requires -RunAsAdministrator

param(
    [string]$DistroUrl=$env:DISTRO_URL,
    [string]$GitBranch=$env:GIT_BRANCH,
    [string]$InstallDir=$env:INSTALL_DIR,
    [string]$WslName=$env:WSL_NAME,
    [string]$WslUsername=$env:WSL_USERNAME
)

if (-not "$InstallDir") {
    $InstallDir = "${env:LOCALAPPDATA}\dev-bootstrap"
}
if (-not "$GitBranch") {
    $GitBranch = "master"
}
if (-not "$DistroUrl") {
    $DistroUrl = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-Container-Base.latest.x86_64.tar.xz"
}
if (-not "$WslName") {
    $WslName = "rocky-9"
}
if (-not "$WslUsername") {
    $WslUsername = $env:USERNAME.toLower()
}

Write-Debug "Check for WSL"
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne "Enabled") {
    Write-Debug "Enabling WSL"
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    Write-Information "Restart required.  Please restart, then run this script again"
    exit
}
else {
    Write-Information "Checking for WSL update"
    wsl --update
}

Write-Information "Set WSL default version to 2"
wsl --set-default-version 2

Write-Information "Import WSL distribution"
$console = ([console]::OutputEncoding)
[console]::OutputEncoding = New-Object System.Text.UnicodeEncoding
$wslMatcher = (wsl --list --quiet | Select-String -Pattern "(?m)^$WslName$")
[console]::OutputEncoding = $console
if (-not $wslMatcher.Matches) {
    Write-Information "WSL distribution $WslName not yet installed, installing"
    $distroCache = "$InstallDir\distrocache"
    $null = New-Item -Path "$distroCache" -Type Directory -Force

    $wslDir = "${env:LOCALAPPDATA}\$WslName"
    $null = New-Item -Path "$wslDir" -Type Directory -Force

    $distroFile = "$distroCache\$WslName.tar.xz"
    if (-not (Test-Path -Path "$distroFile" -PathType Leaf)) {
        Start-BitsTransfer -Source "$DistroUrl" -Destination "$distroFile"
    }

    $wslVolume = "$wslDir\volume"
    wsl --import "$WslName" "$wslVolume" "$distroFile"

    Write-Information "Configure WSL $WslName"
    wsl --distribution "$WslName" --user root --exec `
        bash -c "
            . /etc/os-release
            if [[ `"`${ID_LIKE}`" =~ rhel ]]; then
              dnf install --assumeyes systemd
            fi
    
            cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true
[user]
default=$WslUsername
EOF
            chmod 0644 /etc/wsl.conf
            "
    # terminate to satisfy the 8 second rule (may need to switch to shutdown)
    #   https://learn.microsoft.com/en-us/windows/wsl/wsl-config#the-8-second-rule
    wsl --terminate "$WslName"
}

Write-Information "WSL user $WslUsername"
wsl --distribution "$WslName" --user root --exec `
    bash -c "grep '$WslUsername' /etc/passwd"
if (-not $?) {
    Write-Information "$WslUsername does not exist, creating..."
    wsl --distribution "$WslName" --user root --exec `
        bash -c "
useradd --create-home '$WslUsername' --shell /bin/bash
dnf install --assumeyes sudo
mkdir --parents /etc/sudoers.d
echo '$WslUsername ALL=(ALL) NOPASSWD:ALL' > '/etc/sudoers.d/$WslUsername'
chmod 0440 '/etc/sudoers.d/$WslUsername'
        "
}

Write-Information "Setup ansible"
$configureAnsible = "$env:TEMP\ConfigureRemotingForAnsible.ps1"
Start-BitsTransfer `
    -Source "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1" `
    -Destination "$configureAnsible"
Write-Information "Running $configureAnsible"
powershell.exe -NoProfile -ExecutionPolicy ByPass -File "$configureAnsible" -DisableBasicAuth -EnableCredSSP
winrm set winrm/config/Winrs '@{AllowRemoteShellAccess="true"}'
Enable-WSManCredSSP -Role Server -Force

Write-Information "Link config inside wsl"
$wslPathInstallDir = wsl --distribution "$WslName" --exec wslpath "$InstallDir"
wsl --distribution "$WslName" --user "$WslUsername" --exec bash -c @"
dir="$wslPathInstallDir"

mkdir --parents "`${dir}"
config="`${dir}/config.yml"
if [[ ! -f "`${config}" ]]; then
  touch "`${config}"
fi

wsl_config_dir="`${HOME}/.config/dev-bootstrap"
mkdir --parents "`${wsl_config_dir}"
wslconfig="`${wsl_config_dir}/config.yml"
if [[ ! -e "`${wslconfig}" ]]; then
  ln --symbolic "`${config}" "`${wslconfig}"
fi
"@

Write-Information "Switch to bash to complete the bootstrap"
if ("$GitBranch" -eq "unversioned") {
    Write-Information "Use local unversioned"
    wsl --distribution "$WslName" --user "$WslUsername" --cd "$PSScriptRoot" --exec `
        bash -c "GIT_BRANCH=$GitBranch ./bootstrap.sh"
}
else {
    Write-Information "Use remote branch $GitBranch"
    wsl --distribution "$WslName" --user "$WslUsername" --cd "$PSScriptRoot" --exec `
        bash -c @"
script="/tmp/dev-bootstrap"
curl "https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/$GitBranch/bootstrap.sh" \
    --output "`${script}"
GIT_BRANCH='$GitBranch' "`${script}"
"@
}
