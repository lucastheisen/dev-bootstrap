# Interpolated by wincreds vars plugin single quote ' for username
# and password prevents vairable interpolation if `$` is part of the 
# value, while using double quote " for credsJsonPath allows for
# use of `$env:LOCALAPPDATA` in the value.
$username = '{{USERNAME}}'
$password = '{{PASSWORD}}'
$credsJsonPath = "{{CREDS_JSON}}"

$credsDir = Split-Path $credsJsonPath
if (-not (Test-Path -LiteralPath ($credsDir))) {
    New-Item -Path $credsDir -ItemType Directory -Force | Out-Null
}

$creds = New-Object -TypeName PSCredential $username,$($password | ConvertTo-SecureString -AsPlainText -Force)
Select-Object -InputObject $creds Username,@{Name="Password";Expression = {$_.Password | ConvertFrom-SecureString}} `
    | ConvertTo-Json `
    | Out-File $credsJsonPath

ConvertTo-Json @{Username = $creds.Username; Password = $creds.GetNetworkCredential().Password} `
    | Write-Output
