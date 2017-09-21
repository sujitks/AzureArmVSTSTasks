Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"


$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$Location = Get-VstsInput -Name Location -Require

#
# Azure-NewResourceGroup.ps1
#


Write-Host "Starting Azure-NewResourceGroup"

#Save-Module -Name VstsTaskSdk -Path .\ for get the Powershell VSTS SDK
# see https://github.com/Microsoft/vsts-task-lib/tree/master/powershell/Docs
Trace-VstsEnteringInvocation $MyInvocation

. .\AzureRmSetup.ps1

try {
  Write-Host "ResourceGroupName: " $ResourceGroupName
  Write-Host "Location: " $Location

  #setup the azure rm subscription

  $checkResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction $ErrorActionPreference


} catch {

  if ($Error[0].Exception.Message -match "Provided resource group does not exist")
  {
    Write-Host ("Resource Group {0} not found, creating" -f $ResourceGroupName)
  }
  elseif ($null -ne $checkResourceGroup)
  {
    Write-Host ("Resource Group {0} already exists, nothing to do" -f $ResourceGroupName)
  }
  else
  {
    throw
  }

  if ($null -eq $checkResourceGroup)
  {
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location

  }
  else {
    Write-Host ("Resource Group {0} already exists, nothing to do" -f $ResourceGroupName)
  }


} finally {
  #Trace-VstsLeavingInvocation $MyInvocation
}

Write-Host "Ending Azure-NewResourceGroup"
