Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

Write-Host ("Setting up the azure subscription access")
. .\AzureRmSetup.ps1

function Read-Psd1
{
  #http://stackoverflow.com/a/29423244
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]
    [hashtable]$data
  )
  return $data
}

function Set-AADSCConfiguration {
  param
  (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $AutomationAccountName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $DscConfigurationFilePath,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $DscConfigurationFilePathData,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $RecompileEvenIfNoChanges
  )
  Write-Host "Set-AADSCConfiguration"
  Write-Host "ResourceGroupName: $ResourceGroupName"
  Write-Host "AutomationAccountName: $AutomationAccountName"
  Write-Host "DscConfigurationFilePath: $DscConfigurationFilePath"
  Write-Host "DscConfigurationFilePathData: $DscConfigurationFilePathData"
  Write-Host "RecompileEvenIfNoChanges: $RecompileEvenIfNoChanges"
  $DscConfigurationFileName = [System.IO.Path]::GetFileNameWithoutExtension($DscConfigurationFilePath)

  try
  {
    $config = Get-AzureRmAutomationDscConfiguration -Name $DscConfigurationFileName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
  }
  catch
  {
    Write-Verbose ("Config not found - {0}" -f $_)
  }

  if ($null -eq $config)
  {
    Write-Verbose ("Configuration does not exist in automation account {0}, importing" -f $AutomationAccountName)
  }
  else
  {
    $tempFolder = [System.IO.Path]::GetTempPath()
    Write-Verbose "Exporting current DSC configuration to $tempfolder\$DscConfigurationFileName.ps1 for comparisons"
    Export-AzureRmAutomationDscConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $DscConfigurationFileName -OutputFolder $tempFolder -ErrorAction SilentlyContinue -Force | Out-Null
    if (Test-Path "$tempFolder\$DscConfigurationFileName.ps1")
    {
      $oldContent = Get-Content "$tempFolder\$DscConfigurationFileName.ps1" -Raw
      $newContent = Get-Content $DscConfigurationFilePath -Raw
      if ($oldContent -eq $newContent)
      {
        if ($RecompileEvenIfNoChanges -eq "False")
        {
          Write-Verbose "Configuration has not changed and 'RecompileEvenIfNoChanges' is set to False. Skipping upload and compilation."
          return
        }
      }
      Write-Verbose "Configuration has changed, or 'RecompileEvenIfNoChanges' is set to True. Uploading and re-compiling."
      Remove-Item "$tempFolder\$DscConfigurationFileName.ps1" -Recurse -Force -Confirm:$false
    }
  }

  Write-Verbose "Importing DSC Configuration from $DscConfigurationFilePath"

  $result = Import-AzureRmAutomationDscConfiguration -SourcePath $DscConfigurationFilePath -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Published -Force
  $configurationData = Read-Psd1 $DscConfigurationFilePathData
  Write-Verbose "Starting DSC compilation job"
  $compilationjob = Start-AzureRmAutomationDscCompilationJob -ConfigurationName $result.Name -ConfigurationData $configurationData -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName



  $compilationjobstatus = Get-AzureRmAutomationDscCompilationJob -Id $compilationjob.Id -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName

  while ($compilationjobstatus.Status -ne "Completed")

  {

    Write-Verbose "Waiting for compilation to complete"

    if ($compilationjobstatus.Status -eq "Suspended" -or $compilationjobstatus.Status -eq "Failed")

    {
      Write-Host "----------"
      Write-Host "Exception: "
      Write-Host $compilationjobstatus.Exception
      Write-Host "----------"
      Write-Host "Job output:"
      $CompilationJob | Get-AzureRmAutomationDscCompilationJobOutput -Stream Any
      Write-Host "----------"
      throw "Compilation of DSC configuration failed"
    }
    Start-Sleep -Seconds 5
    $compilationjobstatus = Get-AzureRmAutomationDscCompilationJob -Id $compilationjob.Id -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
  }

  Write-Verbose "Compilation complete. Job output was:"
  $CompilationJob | Get-AzureRmAutomationDscCompilationJobOutput -Stream Any

}

Write-Host ("Starting to creation dsc configuraion in AA")




$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$AutomationAccountName = Get-VstsInput -Name AccountName -Require
$DscConfigurationFilePath = Get-VstsInput -Name DscConfigurationFilePath -Require
$DscConfigurationFilePathData = Get-VstsInput -Name DscConfigurationFilePathData -Require
$RecompileEvenIfNoChanges = Get-VstsInput -Name RecompileEvenIfNoChanges -Require


Set-AADSCConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -DscConfigurationFilePath $DscConfigurationFilePath `
 -DscConfigurationFilePathData $DscConfigurationFilePathData -RecompileEvenIfNoChanges $RecompileEvenIfNoChanges



Write-Host "Ending creation dsc configuraion in AA"
