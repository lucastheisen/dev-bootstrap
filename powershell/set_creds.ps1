$username = "{{USERNAME}}"
$password = "{{PASSWORD}}"
$credsJsonPath = "~/.developer/test-dev-bootstrap/creds.json"

$creds = New-Object -TypeName PSCredential $username,$($password | ConvertTo-SecureString -AsPlainText -Force)
Select-Object -InputObject $creds Username,@{Name="Password";Expression = {$_.Password | ConvertFrom-SecureString}} `
    | ConvertTo-Json `
    | Out-File $credsJsonPath

ConvertTo-Json @{Username = $creds.Username; Password = $creds.GetNetworkCredential().Password} `
    | Write-Output
