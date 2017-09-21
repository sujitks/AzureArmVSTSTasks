Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"


$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$Location = Get-VstsInput -Name Location -Require
$Plan = Get-VstsInput -Name Plan -Require
$AutomationAccountName = Get-VstsInput -Name AccountName -Require
. .\AzureRmSetup.ps1
#
# Azure-NewResourceGroup.ps1
#

try
{
  $automationacc = Get-AzureRmAutomationAccount -Name $AutomationAccountName -ResourceGroupName $ResourceGroupName
}

catch
{
  if ($_ -match "ResourceNotFound\: The Resource \'Microsoft\.Automation\/automationAccounts\/.*under resource group .* was not found")
  {
    Write-Verbose ("Automation account {0} not found, creating" -f $AutomationAccountName)
  }
  else
  {
    throw ("Could not determine if automation account already exists`n{0}" -f $_)
  }
}

if ($null -eq $automationacc)
{
  New-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName -Location $Location -Plan $Plan
}
else
{
  Write-Verbose ("Automation account {0} already exists" -f $AutomationAccountName)
}





Write-Host "Ending Azure new automation account"
