Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

Write-Host ("Setting up the azure subscription access")
. .\AzureRmSetup.ps1




function Get-AzureAAInfo {

  param(

    [Parameter(Mandatory = $true)]

    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]

    [string]$AutomationAccountName

  )

  $aaInfo = $null

  try {

    $aaInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName

  }

  catch {

    throw "Unable to get resource information"

  }



  return $aaInfo

}





function Get-AutomationAccountInformation {



  param(

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName
  )
  Write-Verbose "Resource Group name: $ResourceGroupName"
  Write-Verbose "AutomationAccountName is : $AutomationAccountName"
  Write-Verbose "Fetching automation account information"

  $aaInfo = Get-AzureAAInfo -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue

  if ($null -eq $aaInfo) {
    Write-Verbose "unable to get automation account info"
    Write-Verbose ("Unable to get automation account information for {0} account in {1} resource group" -f $AutomationAccountName,$ResourceGroupName)
    throw $("Unable to get automation account information for {0} account in {1} resource group" -f $AutomationAccountName,$ResourceGroupName)
  }

  else {
	  $aaEndPoint = $aaInfo.EndPoint
	  $aaKey = $aaInfo.PrimaryKey
    Write-Verbose "setting output variable's values"
    Write-Host ("AA end point {0}" -f $aaEndPoint)
    Write-Host ("AA PrimaryKey {0}" -f $aaKey)

#Write-Host "##vso[task.setvariable variable=timestamp]$tstamp"


   Write-Host "##vso[task.setvariable variable=registrationUrl;]$aaEndPoint"
   Write-Host "##vso[task.setvariable variable=registrationKey;]$aaKey"

  }

}

Write-Host ("Starting to get automation account information" -f $ModuleName)


$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$AutomationAccountName = Get-VstsInput -Name AccountName -Require
#$OutputAutomationEndpoint = Get-VstsInput -Name OutputAutomationEndpoint -Require
#$OutputPrimaryKey = Get-VstsInput -Name OutputPrimaryKey -Require


Get-AutomationAccountInformation -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName 


Write-Host "Finished getting the automation account information"
