
<#PSScriptInfo

.VERSION 1.0

.GUID a540e16e-0cf8-4cf0-90f5-8f2d1734a586

.AUTHOR vmehmeri@outlook.com

.TAGS Windows, Linux, MacOS

.LICENSEURI

.PROJECTURI https://github.com/vmehmeri/az-posh.git

.EXTERNALMODULEDEPENDENCIES Az 

#>

<# 

.DESCRIPTION 
 Lists all private IPs for the selected subscription 

#> 
Param()

$subscriptions = (Get-AzSubscription | Select-Object Name | Out-GridView -Title "Select Subscription" -PassThru).Name

foreach($subscription in $subscriptions) {

    set-azcontext $subscription > $null
    az account set --subscription $subscription > $null

    $ResourceIpMap = New-Object PSObject


    write-host "`nChecking Azure Load Balancers..."
    $allLbs = Get-AzLoadBalancer 

    foreach ($lb in $allLbs) {
        $frontendIps = @()
        $frontendConfigs = Get-AzLoadBalancerFrontendIpConfig -LoadBalancer $lb
    
        foreach ($frontendConfig in $frontendConfigs) {
            if (-not [String]::IsNullOrEmpty($frontendConfig.PrivateIpAddress)) {

                $frontendIps += $frontendConfig.PrivateIpAddress
            }
        }

        $ipListStr = [system.String]::Join(",",$frontendIps)
        write-host ("{0} : {1}" -f ($lb.Name, $ipListStr))
        $resourceKey = "{0}/{1}" -f ($lb.ResourceGroupName, $lb.name)
        $ResourceIpMap | add-member Noteproperty $resourceKey $ipListStr
    }

    write-host "`nChecking Virtual Machines..."
    $allNics = Get-AzNetworkInterface

    foreach ($nic in $allNics) {
        $nicIps = @()
        foreach ($ipconfig in $nic.IpConfigurations) {
            $nicIps += $ipconfig.PrivateIpAddress
        }
        $vmName = $nic.name.replace('-nic01','')
        $ipListStr = [system.String]::Join(",",$nicIps)
        write-host ("{0} : {1}" -f ($vmName, $ipListStr))
        $resourceKey = "{0}/{1}" -f ($nic.ResourceGroupName, $vmName)
        $ResourceIpMap | add-member Noteproperty $resourceKey $ipListStr
    }

    write-host "`nChecking Virtual Machine Scalesets..."
    $allVmss = get-azvmss
    foreach ($vmss in $allVmss)
    {
        $ips = @()
        ## Using AZ CLI for this one as it seems complicated to do it via Powershell
        $nicList = (az vmss nic list --resource-group $vmss.ResourceGroupName --vmss-name $vmss.name) | convertfrom-json 
        foreach ($nic in $nicList) {
            foreach ($ipconfig in $nic.IpConfigurations) {
                $ips += $ipconfig.privateipaddress
            }
        }

        $ipListStr = [system.String]::Join(", ",$ips)
        write-host ("{0} : {1}" -f ($vmss.name, $ipListStr))
        $resourceKey = "{0}/{1}" -f ($vmss.ResourceGroupName, $vmss.name)
        $ResourceIpMap | add-member Noteproperty $resourceKey $ipListStr
        
    }   

    write-host "`nChecking Application Gateways..."
    $allAgws = Get-AzApplicationGateway
    foreach ($agw in $allAgws)
    {
        $privateIps = @()
        foreach ($frontendConfig in $agw.FrontendIPConfigurations) {
            if (-not [String]::IsNullOrEmpty($frontendConfig.PrivateIPAddress)) {
                $privateIps += $frontendConfig.PrivateIPAddress
            }
        }
        $ipListStr = [system.String]::Join(", ",$privateIps)
        write-host ("{0} : {1}" -f ($agw.name, $ipListStr))
        $resourceKey = "{0}/{1}" -f ($agw.ResourceGroupName, $agw.name)
        $ResourceIpMap | add-member Noteproperty $resourceKey $ipListStr
        
    }   

    write-host "`nChecking Azure Firewalls..."
    $allFws = Get-AzFirewall
    foreach ($fw in $allFws)
    {
        $privateIps = @()
        foreach ($IpConfig in $fw.IpConfigurations) {
            if (-not [String]::IsNullOrEmpty($IpConfig.privateIpAddress)) {
                $privateIps += $IpConfig.privateIpAddress
            }
        }
        $ipListStr = [system.String]::Join(", ",$privateIps)
        write-host ("{0} : {1}" -f ($fw.name, $ipListStr))
        $resourceKey = "{0}/{1}" -f ($fw.ResourceGroupName, $fw.name)
        $ResourceIpMap | add-member Noteproperty $resourceKey $ipListStr
        
    } 

    $subscriptionName = $subscription.replace(' ', '').replace('/', '').replace('(', '').replace(')', '')
    $ResourceIpMap | convertto-json -depth 30 | Out-File "$subscriptionName-privateIps.json"

    Write-output "Output written to $subscriptionName-privateIps.json"
}
