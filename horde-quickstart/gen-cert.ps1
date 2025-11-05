# check for admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as an Administrator. Please restart PowerShell as Administrator and try again."
    exit
}

$domainName = Read-Host -Prompt "Please enter your full Horde domain name (no https://)"
$numYears = Read-Host -Prompt "Please enter number of years the certificate should be valid for (default 1)"
if ([string]::IsNullOrEmpty($numYears)) {
    $numYears = 1
}

# ask to continue with the given inputs
Write-Host "You have entered the following values:"
Write-Host "Domain Name: $domainName"
Write-Host "Number of Years: $numYears"
$confirmation = Read-Host -Prompt "Do you want to proceed? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled by user."
    exit
}

New-SelfSignedCertificate `
  -DnsName $domainName `
  -CertStoreLocation "Cert:\LocalMachine\My" `
  -NotAfter (Get-Date).AddYears($numYears) `
  -FriendlyName "HordeSelfSigned"

$password = Read-Host -Prompt "Please enter a password to protect the exported .pfx file" -AsSecureString

Get-ChildItem `
  -Path Cert:\LocalMachine\My `
  | Where-Object {$_.FriendlyName -eq "HordeSelfSigned"} `
  | Export-PfxCertificate -FilePath "cert.pfx" `
  -Password $password
