Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

Write-Host "collecting vsts input params"
$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$StorageAccountName = Get-VstsInput -Name StorageAccountName -Require

$TemplateDeploymentContainerName = Get-VstsInput -Name StorageAccountContainerName -Require
$PathToTemplateFolder = Get-VstsInput -Name PathToTemplateFolder -Require
$TemplateFileName = Get-VstsInput -Name TemplateFileName -Require
$DeploymentMod = Get-VstsInput -Name DeploymentMode -Require
$TemplateVersion = Get-VstsInput -Name TemplateVersion -Require
$ARMDeploymentName = Get-VstsInput -Name ARMDeploymentName -Require
$EnvironmentName = Get-VstsInput -Name EnvironmentName -Require
$TemplateParameterFile = Get-VstsInput -Name TemplateParameterFile -Require

. .\AzureRmSetup.ps1


function New-ARMTemplateDeployment {

  param
  (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageContainerName,
    [Parameter(Mandatory = $true)]
    $PathToTemplateFolder,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateFileName,
    [Parameter(Mandatory = $true)]
    $DeploymentMode,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateVersion,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ARMDeploymentName,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentName,
    [Parameter(Mandatory = $false)]
    [string]$TemplateParameterFile
  )

  # Check for existence of storage account and resource group
  Write-Host ("Get storage account information")
  $storageAccount = Get-AzureRmStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }

  if ($null -eq $storageAccount)
  {
    throw ("Storage account {0} does not exist in the {1} resource group. Please create the deployment storage account" -f $StorageAccountName,$ResourceGroupName)
  }
  Write-Host ("storage account exists")
  $resourcegroup = Get-AzureRmResourceGroup -Name $ResourceGroupName
  if ($null -eq $resourcegroup)
  {
    throw ("Resource group {0} does not exist, Please create the resource group and try again." -f $ResourceGroupName)
  }
  Write-Host ("Resource Group exists")
  #storageaccount keys
  $StorageAccountAccessKey = Get-AzureRmStorageAccountKey -Name $storageAccount.StorageAccountName -ResourceGroupName $storageAccount.ResourceGroupName

  if ($null -eq $StorageAccountAccessKey)
  {
    throw "Storage accunt keys not found for storage account $StorageAccountName"
  }

  $key = $StorageAccountAccessKey.key1

  if ($null -eq $key) #in case it comes as array
  {
    $key = $StorageAccountAccessKey[0].Value
  }
  Write-Host ($key)

  $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key

  Write-Host "Getting the deployment container"

  $TemplateDeploymentContainer = Get-AzureStorageContainer -Context $context | Where-Object { $_.Name -eq $StorageContainerName }

  if ($null -eq $TemplateDeploymentContainer)
  {
    Write-Host ("Storage container {0} does not exist on storage account {1}, creating" -f $StorageContainerName,$StorageAccountName)
    New-AzureStorageContainer -Name $StorageContainerName -Permission Blob -Context $context
	$TemplateDeploymentContainer = Get-AzureStorageContainer -Context $context | Where-Object { $_.Name -eq $StorageContainerName }
  }

  Write-Host "Check and set the permission on container"
  Write-Host ("storage container acl {0}" -f $TemplateDeploymentContainer.Permission.PublicAccess)
  #set the read permission on the container
  if ($TemplateDeploymentContainer.Permission.PublicAccess -ne "Blob")
  {
    Set-AzureStorageContainerAcl -Name $StorageContainerName -Permission Blob -Context $context
  }

  # upload all the deployment files to the container
  $files = Get-ChildItem -Path $PathToTemplateFolder -File -Recurse
  Write-Host ("starting to upload the template files")
  $templateBlob = $null
  $templateParameterBlob = $null

  foreach ($file in $files)
  {
    #lets create the target blob name such it should form folder structure as NameOfARMTemplates\Version\Env\NameOfTheFile.json
    #for example SharepointTemplates could be Sharepoint\1.2.1.2\Dev\sharepoint.json and Sharepoint\1.2.1.2\Dev\sharepoint.parameters.json
    #this is to allow keeping the dev/test/preprod specific template seperately for the deployment.
    $blobname = ("{0}\{1}\{2}\{3}" -f $ARMDeploymentName,$TemplateVersion,$EnvironmentName,($file.FullName.Replace($PathToTemplateFolder,"")).TrimStart("\"))

    #check the existing blob in case of a redeployment
    $blob = Get-AzureStorageBlob -Container $StorageContainerName -Context $context | Where-Object { $_.Name -eq ($blobname -replace "\\","/") }

    if ($null -eq $blob)
    {
      Write-Host ("Template File {0} does not exist in storage account {1} in container {2}, adding now" -f $blobname,$StorageAccountName,$TemplateDeploymentContainer)
      $blob = Set-AzureStorageBlobContent -File $file.FullName -Container $StorageContainerName -Blob $blobname -Context $context
    }
    else
    {
      $varMd5Provider = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
      $LocalFileChecksum = [System.Convert]::ToBase64String($varMd5Provider.ComputeHash([System.IO.File]::ReadAllBytes($file.FullName)))

      Write-Host ("File {0} already exists in storage account {1} in container {2}, comparing with local" -f $blobname,$StorageAccountName,$TemplateDeploymentContainer)

      if ($blob.ICloudBlob.Properties.ContentMD5 -ne $LocalFileChecksum)
      {
        Write-Host ("File is different to local, overwriting the file")
        $blob = Set-AzureStorageBlobContent -File $file.FullName -Container $StorageContainerName -Blob $blobname -Context $context -Force
      }
    }

    if ($file.Name -eq $TemplateFileName)
    {
      $templateBlob = $blob
    }

    if ($file.Name -eq $TemplateParameterFile)
    {
      $templateParameterBlob = $blob
    }
  }

  $armDeploymentArgs = @{
    ResourceGroupName = $ResourceGroupName
    Name = $ARMDeploymentName
    TemplateUri = $templateBlob.ICloudBlob.StorageUri.PrimaryUri
    Mode = $DeploymentMode
  }

  if ($null -ne $templateParameterBlob)
  {
    $armDeploymentArgs.TemplateParameterUri = $templateParameterBlob.ICloudBlob.StorageUri.PrimaryUri
  }

  Write-Host "Deployment properties:"
  Write-Host ($armDeploymentArgs | Format-List | Out-String)

  # Deployment of the template
  New-AzureRmResourceGroupDeployment @armDeploymentArgs -Verbose

}

Write-Host "Starting deployment of ARM template"
New-ARMTemplateDeployment -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $TemplateDeploymentContainerName -PathToTemplateFolder $PathToTemplateFolder -TemplateFileName $TemplateFileName `
   -DeploymentMode $DeploymentMod -TemplateVersion $TemplateVersion -ARMDeploymentName $ARMDeploymentName -EnvironmentName $EnvironmentName -TemplateParameterFile $TemplateParameterFile

Write-Host "Ending deployment of ARM template"
