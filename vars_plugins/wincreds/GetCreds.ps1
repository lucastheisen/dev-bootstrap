# Interpolated by wincreds vars plugin using double quote " allows for
# use of `$env:LOCALAPPDATA` in the value.
$credsJsonPath = "{{CREDS_JSON}}"

$ErrorActionPreference = "SilentlyContinue"

if (-not (Test-Path -Path $credsJsonPath -PathType Leaf)) {
    Write-Error "creds.json not found" -ErrorAction Stop
}
$credsJson = Get-Content $credsJsonPath;
if ($null -eq $credsJson) {
    Write-Error "Empty creds.json" -ErrorAction Stop
}

$credsEncrypted = ($credsJson | ConvertFrom-Json)
if ((-not $?) -or (-not $credsEncrypted.UserName) -or (-not $credsEncrypted.Password)) {
    Write-Error "Invalid creds.json: [$credsJson]" -ErrorAction Stop
}

$password = ($credsEncrypted.Password | ConvertTo-SecureString)
if (-not $?) {
    Write-Error "Invalid creds.json, password not encrypted correctly" -ErrorAction Stop
}

$creds = New-Object -TypeName PSCredential $credsEncrypted.UserName,$password
if (-not $?) {
    Write-Error "Invalid creds.json" -ErrorAction Stop
}

Add-Type -AssemblyName System.DirectoryServices.AccountManagement

$valid = $false
try {
    $ds = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain) `
        -ErrorAction "Continue"
    if ($ds.ValidateCredentials($creds.GetNetworkCredential().UserName, $creds.GetNetworkCredential().password)) {
        $valid = $true
    }
}
catch {
    Write-Debug "Domain not supported"
}

$ds = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
if ($ds.ValidateCredentials($creds.GetNetworkCredential().UserName, $creds.GetNetworkCredential().password)) {
    $valid = $true
}

if ($valid) {
    Select-Object -InputObject $creds Username,@{Name="Password";Expression = {$_.Password | ConvertFrom-SecureString}} `
        | ConvertTo-Json `
        | Out-File $credsJsonPath
    ConvertTo-Json @{Username = $creds.Username; Password = $creds.GetNetworkCredential().Password} `
        | Write-Output
}
else {
    Write-Error "Bad credentials" -ErrorAction Stop
}

