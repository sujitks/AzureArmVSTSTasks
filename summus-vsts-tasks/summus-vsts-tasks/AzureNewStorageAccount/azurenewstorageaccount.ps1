Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"


$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$Location = Get-VstsInput -Name Location -Require
$Type = Get-VstsInput -Name Get-Content -Require
$StorageAccountName = Get-VstsInput -Name AccountName -Require

#
# Azure-NewResourceGroup.ps1
#


Write-Host "Starting task to create new storage account"

#Save-Module -Name VstsTaskSdk -Path .\ for get the Powershell VSTS SDK
# see https://github.com/Microsoft/vsts-task-lib/tree/master/powershell/Docs
Trace-VstsEnteringInvocation $MyInvocation

. .\AzureRmSetup.ps1


#function Set-StorageAccount {

#    param (
#        [Parameter(Mandatory=$true)]
#        [ValidateLength(3,24)]
#        [string]$StorageAccountName,
#        [string]$ResourceGroupName,
#        [ValidateSet("Premium_LRS","Standard_GRS","Standard_LRS","Standard_RAGRS","Standard_ZRS")]
#        [string]$Type,
#        [string]$Location
#    )




# First check the resource group exists, if not create
if ($null -eq (Get-AzureRmResourceGroup | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName }))
{
  throw ("Resource group {0} does not exist in this subscription. Use a step to create the resource group before this step is run." -f $ResourceGroupName)
}

# Create the storage account if it doesn't exist
$StorageAccountNameLower = $StorageAccountName.ToLower();

$checkStorageAccount = Find-AzureRmResource -ResourceType "Microsoft.Storage/storageAccounts" -ResourceNameContains $StorageAccountNameLower -ApiVersion "2016-07-01"

if ($null -eq $checkStorageAccount)
{
  Write-Verbose ("Storage Account {0} does not exist, creating" -f $StorageAccountNameLower)

  New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountNameLower -Type $Type -Location $Location
}
else
{
  Write-Verbose ("Storage account {0} already exists" -f $StorageAccountNameLower)

  $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $checkStorageAccount.ResourceGroupName -Name $checkStorageAccount.ResourceName

  if ($storageAccount.AccountType -ne ($Type -replace "_"))
  {
    Write-Verbose ("Account type of Storage Account {0} ({1}) does not match desired ({2}), modifying" -f $StorageAccountNameLower,$storageAccount.AccountType,$Type)
    Set-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountNameLower -Type $Type
  }
}
#}



Write-Host "Ending Azure new storage account"
