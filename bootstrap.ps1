#Requires -RunAsAdministrator

Write-Debug "Check for WSL"
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne "Enabled") {
    Write-Debug "Enabling WSL"
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    Write-Information "Restart required.  Please restart, then run this script again"
    exit
}

Write-Debug "Check for Ubuntu18"
if (((Get-AppxPackage -Name CanonicalGroupLimited.Ubuntu18.04onWindows).Status -ne "Ok")) {
    $ProgressPreference = "SilentlyContinue"
    $ubuntuAppx = "$env:USERPROFILE\Downloads\ubuntu.appx"
    Write-Information "Downloading ubuntu... This may take a while."
    Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile $ubuntuAppx -UseBasicParsing

    Write-Information "Installing ubuntu application"
    Add-AppxPackage -Path $ubuntuAppx

    Write-Information "Installing ubuntu application"
    ubuntu1804.exe install --root
}

Write-Debug "Check if Ubuntu18 needs initialization"
if ($(ubuntu1804.exe run whoami) -eq "root") {
    $wslUsername = Read-Host -Prompt 'What is your WSL username (will be created if it does not exist)?'

    Write-Information "In passwd  [$(ubuntu1804.exe run "cat /etc/passwd | grep $wslUsername")]"
    if (-not ((ubuntu1804.exe run "cat /etc/passwd | grep $wslUsername") -match "^$wslUsername`:")) {
        Write-Information "$wslUsername does not exist...  Creating"
        ubuntu1804.exe run "adduser $wslUsername"
    }

    Write-Information "Add sudo ALL for $wslUsername"
    ubuntu1804.exe run "echo '$wslUsername ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$wslUsername"
    ubuntu1804.exe run "chmod 0440 /etc/sudoers.d/$wslUsername"

    Write-Information "Setting ubuntu default user to $wslUsername"
    ubuntu1804.exe config --default-user "$wslUsername"
}

Write-Information "Configuring windows for ansible"
# https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html#winrm-setup
$file = "$env:TEMP\ConfigureRemotingForAnsible.ps1"
Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1" `
    -UseBasicParsing `
    -OutFile $file
powershell.exe -ExecutionPolicy ByPass -File $file

Write-Information "Running dev-bootstrap ansible playbook"
$script = (Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/master/bootstrap.sh" `
    -UseBasicParsing).Content
ubuntu1804.exe run "$script"
