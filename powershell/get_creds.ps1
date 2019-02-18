$credsJsonPath = "~/.developer/test-dev-bootstrap/creds.json"

if (-not (Test-Path -Path $credsJsonPath -PathType Leaf)) {
    Write-Error "creds.json not found" -ErrorAction Stop
}

$creds = Get-Content $credsJsonPath `
    | ConvertFrom-Json `
    | ForEach-Object {New-Object -TypeName PSCredential $_.Username,$($_.Password | ConvertTo-SecureString)}

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
