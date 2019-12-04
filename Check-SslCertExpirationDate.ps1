
<#PSScriptInfo

.VERSION 1.0

.GUID 18594c68-4e92-4c8f-a9a9-95a43e19d6e0

.AUTHOR v.dantas.mehmeri

.TAGS Windows, Linux, MacOS

.PROJECTURI https://github.com/vmehmeri/az-posh.git

.EXTERNALMODULEDEPENDENCIES Az 

.DESCRIPTION 
 It tests the expiration date of a certificate using openssl utility against a public hostname, 
 or a private hostname that can be accessed from the server where the script is running. 

 This script requires OpenSSL and Grep utilities to be installed.

#>

<#
.PARAMETER Hostname
 The target hostname

.PARAMETER Port
 The HTTPS port to connect to it. If not specified, default port 443 will be used.

.EXAMPLE 
 .\CheckSslCertExpirationDate.ps1 -Hostname www.example.com

 .PRE-REQUISITES
 OpenSSL
 Grep
#>
param(
    [Parameter(Mandatory=$true)]
    [String] $Hostname,

    [Parameter(Mandatory=$false)]
    [String] $Port = "443"
)

try {
    $_ = grep --version 
} catch {
    Write-Error "You must install grep and add it to your PATH in order to use this script"
    exit 0
}

try {
    $_ = openssl version 
} catch {
    write-error "You must install openssl and add it to your PATH in order to use this script"
    exit 0
}


try {

    $ExpirationDateStr = (echo "" | openssl s_client -connect ($Hostname+":$Port") -servername $Hostname 2>null | openssl x509 -noout -dates | grep -oP '(?<=notAfter=).*')
    $_ExpirationDateArray = $ExpirationDateStr.split(' ')
    $ExpDay = $_ExpirationDateArray[1]
    $ExpMonth = $_ExpirationDateArray[0]
    $ExpYear = $_ExpirationDateArray[-2]

    $ExpirationDate = Get-Date -Date ("{0} {1} {2}" -f $ExpMonth, $ExpDay, $ExpYear)

    Write-Output "Certificate expiration date: $ExpirationDateStr"

    $Now = Get-Date
    if ($ExpirationDate -lt $Now) {
        Write-Host "Certificate has expired" -ForegroundColor red 
    }

    if ($ExpirationDate -lt $Now.AddDays(30)) {
        Write-Host "Certificate is expiring soon (less than 30 days)" -ForegroundColor yellow 
    }

    if ($ExpirationDate -gt $Now.AddDays(60)) {
        Write-Host "Certificate expiration date is at least 60 days from now" -ForegroundColor green 
    }
} catch {
    Write-Warning "Could not verify certificate"
    
}
