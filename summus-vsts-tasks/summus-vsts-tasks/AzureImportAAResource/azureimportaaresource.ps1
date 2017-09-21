Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

Write-Host ("Setting up the azure subscription access")
. .\AzureRmSetup.ps1


function Import-AAResource
{
  param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,
    [Parameter(Mandatory = $true)]
    [string]$storageAccount,
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    [Parameter(Mandatory = $true)]
    [string]$RequiredVersion,
    [Parameter(Mandatory = $true)]
    [string]$DscBlobContainerName)
  $tempPath = $env:Agent_ReleaseDirectory #[System.IO.Directory]::GetCurrentDirectory()
  $folderName = [System.IO.Path]::Combine($tempPath,$ModuleName)
  $zipFileName = ("{0}\{1}.zip" -f $tempPath,$ModuleName)
	
	 Write-Host("Zip file {0} is being created" -f $zipFileName)
  #get a folder for the module
  if (-not (Test-Path $folderName))
  {
    Write-Host "creating folder"
    [System.IO.Directory]::CreateDirectory($folderName)
  }
	Write-Host("Module {0} of version {1} is being downloaded " -f $ModuleName, $RequiredVersion)

	Write-Host ("folder {0} created" -f $folderName)
		if($null -ne $RequiredVersion)
		{
			Write-Host("Module {0} of version {1} is being downloaded " -f $ModuleName, $RequiredVersion)
			Save-Module $ModuleName -Path $folderName -Repository PSGallery -RequiredVersion $RequiredVersion
		}
		else{
			Write-Host("Lates module: {0} is being downloaded " -f $ModuleName)
			Save-Module $ModuleName -Path $folderName -Repository PSGallery #-RequiredVersion $RequiredVersion
		}

	$moduleFileName = ("{0}.psd1" -f $ModuleName)
	Write-Host ("searching the module file {0} in folder {1} recursevely" -f $moduleFileName, $tempPath)

	$modulePath = Get-ChildItem -Path $tempPath -Recurse -Filter $moduleFileName | Select-object -first 1
	$zipSourceFolder = $modulePath.DirecoryName

	write-host("{0} is installed in {1}, packing up" -f $ModuleName, $modulePath.DirectoryName)
	Write-Host $modulePath.DirectoryName
	

  ZipFiles -zipfilename $zipFileName -sourcedir $modulePath.DirectoryName
  Write-Host $zipFileName

  uploadBlobToContainer -fileToUpload $zipFileName -StorageAccountName $storageAccount -ResourceGroupName $ResourceGroupName -StorageAccountContainerName $DscBlobContainerName -BlobPrefix $ModuleName -FilePath $tempPath
  $blobName = ("https://{0}.blob.core.windows.net/{1}/{3}/{3}.zip" -f $storageAccount,$DscBlobContainerName,$blobPrefix,$ModuleName)
  New-AzureRmAutomationModule -Name $ModuleName -ContentLink $blobName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName

  
}


function ZipFiles
{
  param(
    [string]$zipfilename,
    [string]$sourcedir)
  Add-Type -Assembly System.IO.Compression.FileSystem
  $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal

	Write-Host ("Creating zip {0} from the content of {1} " -f $zipfilename, $sourcedir)


  [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedir,
    $zipfilename,$compressionLevel,$false)
}

function uploadBlobToContainer {
  param(
    [string]
    $fileToUpload,
    [string]
    $StorageAccountName,
    [string]
    $ResourceGroupName,
    [string]
    $StorageAccountContainerName,
    [string]
    $BlobPrefix,
    [string]
    $FilePath

  )
  $storageContainerName = $StorageAccountContainerName
  $storageAccount = Get-AzureRmStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }

  if ($null -eq $storageAccount)
  {
    throw ("Storage account {0} does not exist in the {1} resource group. Please create the deployment storage account" -f $StorageAccountName,$ResourceGroupName)
  }

  $resourcegroup = Get-AzureRmResourceGroup -Name $ResourceGroupName
  if ($null -eq $resourcegroup)
  {
    throw ("Resource group {0} does not exist, Please create the resource group and try again." -f $ResourceGroupName)
  }

  #storageaccount keys
  $StorageAccountAccessKey = Get-AzureRmStorageAccountKey -Name $storageAccount.StorageAccountName -ResourceGroupName $storageAccount.ResourceGroupName

  if ($null -eq $StorageAccountAccessKey)
  {
    throw "Storage accunt keys not found for storage account $StorageAccountName"
  }

  $key = $StorageAccountAccessKey.key1

  if ($null -eq $key) #in case it comes as array
  { Set-Location
    $key = $StorageAccountAccessKey[0].Value
  }

  $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key

  $TemplateDeploymentContainer = Get-AzureStorageContainer -Context $context | Where-Object { $_.Name -eq $storageContainerName }
  if ($null -eq $TemplateDeploymentContainer)
  {
    Write-Verbose ("Storage container {0} does not exist on storage account {1}, creating" -f $storageContainerName,$StorageAccountName)
    New-AzureStorageContainer -Name $storageContainerName -Permission Blob -Context $context
  }

  #set the read permission on the container
  if ($TemplateDeploymentContainer.Permission.PublicAccess -ne "Blob")
  {
    Set-AzureStorageContainerAcl -Name $storageContainerName -Permission Blob -Context $context
  }

  Write-Host ("Blobprefix is {0} and filetoupload is {1} and filepath is {2}" -f $BlobPrefix,$fileToUpload,$FilePath)
  $fileName = [System.IO.Path]::GetFileName($fileToUpload)
  $blobname = ("{0}\{1}" -f $BlobPrefix,$fileName)
  Write-Host ("Blob name {0} is used for uploading the module" -f $blobname)
  #check the existing blob in case of a redeployment
  $blob = Get-AzureStorageBlob -Container $storageContainerName -Context $context | Where-Object { $_.Name -eq ($blobname -replace "\\","/") }

  if ($null -eq $blob)
  {
    Write-Host ("Template File {0} does not exist in storage account {1} in container {2}, adding now" -f $blobname,$StorageAccountName,$StorageAccountContainer)
    $blob = Set-AzureStorageBlobContent -File $fileToUpload -Container $storageContainerName -Blob $blobname -Context $context
  }
  else
  {
    $varMd5Provider = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $LocalFileChecksum = [System.Convert]::ToBase64String($varMd5Provider.ComputeHash([System.IO.File]::ReadAllBytes($fileToUpload)))

    Write-Host ("File {0} already exists in storage account {1} in container {2}, comparing with local" -f $blobname,$StorageAccountName,$storageContainerName)

    if ($blob.ICloudBlob.Properties.ContentMD5 -ne $LocalFileChecksum)
    {
      Write-Host ("File is different to local, overwriting the file")
      $blob = Set-AzureStorageBlobContent -File $fileToUpload -Container $storageContainerName -Blob $blobname -Context $context -Force
    }
  }




}


Write-Host ("Starting to Import {0} into azure automation account" -f $ModuleName)

$ResourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$AutomationAccountName = Get-VstsInput -Name AccountName -Require
$storageAccount = Get-VstsInput -Name StorageAccountName -Require
$ModuleName = Get-VstsInput -Name ModuleName -Require
$RequiredVersion = Get-VstsInput -Name RequiredVersion -Require
$DscBlobContainerName = Get-VstsInput -Name DscBlobContainerName -Require

Import-AAResource -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -storageAccount $storageAccount -ModuleName $ModuleName `
   -RequiredVersion $RequiredVersion -DscBlobContainerName $DscBlobContainerName


Write-Host "Ending Import of DSC resource to AA"
