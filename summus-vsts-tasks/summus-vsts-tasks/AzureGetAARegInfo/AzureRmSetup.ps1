

function Set-AzureRMSubscription {
  param(
    [string]$password,
    [string]$clientId,
    [string]$tenantId,
    [string]$subscriptionId
  )
  $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
  $creds = New-Object System.Management.Automation.PSCredential ($clientId,$securePassword)
  Write-Host "Authenticating Azure RM with Service Principal (via Azure SPN script module)"
  Add-AzureRmAccount -Credential $creds -ServicePrincipal -tenantId $tenantId -SubscriptionId $subscriptionId

}

$tenantId = Get-VstsTaskVariable -Name "AzureTenantId"
$clientId = Get-VstsTaskVariable -Name AzureSPNAppID
$password = Get-VstsTaskVariable -Name AzureSPNToken
$subscriptionId = Get-VstsTaskVariable -Name AzureSubscriptionId


Write-Host "azuretenantid $tenantId"
Write-Host "clientid $clientId"
Write-Host "subscid $subscriptionId"

Set-AzureRMSubscription -tenantId $tenantId -ClientId $clientId -password $password -SubscriptionId $subscriptionId



