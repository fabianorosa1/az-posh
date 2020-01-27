param(
    [Parameter(Mandatory=$true)]
    [String] $ManagementGroupId,

    [Parameter(Mandatory=$false)]
    [Float] $Version = 1.0
)

#Requires -Modules Az.Blueprint

Import-AzBlueprintWithArtifact -Name CAFBlueprint -ManagementGroupId $ManagementGroupId -InputPath  ".\caf-foundation-and-landing-zone" -ErrorAction Stop

# Get the blueprint we just created
$bp = Get-AzBlueprint -Name CAFBlueprint -ManagementGroupId $ManagementGroupId -ErrorAction Stop

# Publish new version 
Publish-AzBlueprint -Blueprint $bp -Version $Version 


## Assign the blueprint to a subscription:

## Get the version of the blueprint you want to assign, which we will pas to New-AzBlueprintAssignment
$publishedBp = Get-AzBlueprint -ManagementGroupId $ManagementGroupId -Name CAFBlueprint -LatestPublished

## Each resource group artifact in the blueprint will need a hashtable for the actual RG name and location
$sharedSvcsRgHash = @{ name="$ManagementGroupId-SharedSvcs-rg"; location = "westeurope" }
$netRgHash = @{ name="$ManagementGroupId-VNet-rg"; location = "westeurope" }
$migrateRgHash = @{ name="$ManagementGroupId-Migrate-rg"; location = "westeurope" }
$identityRgHash = @{ name="$ManagementGroupId-Identity-rg"; location = "westeurope" }
$applicationRgHash = @{ name="$ManagementGroupId-Application-rg"; location = "westeurope" }

## all other (non-rg) parameters are listed in a single hashtable, with a key/value pair for each parameter
# $parameters = @{ principalIds="caeebed6-cfa8-45ff-9d8a-03dba4ef9a7d" }

## All of the resource group artifact hashtables are themselves grouped into a parent hashtable
## the 'key' for each item in the table should match the RG placeholder name in the blueprint
# $rgArray = @{ SingleRG = $rgHash }

## Assign the new blueprint to the specified subscription (Assignment updates should use Set-AzBlueprintAssignment
# New-AzBlueprintAssignment -Name "UniqueBlueprintAssignmentName" -Blueprint $publishedBp -Location eastus -SubscriptionId "00000000-1111-0000-1111-000000000000" -ResourceGroupParameter $rgArray -Parameter $parameters