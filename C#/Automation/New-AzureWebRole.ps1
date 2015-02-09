Param(
      [string]$service,
      [string]$containerName,
      [string]$config,
      [string]$package,
      [string]$slot="Production")
 
 
Function Upload-Package($package, $containerName){
    $blob = "$service.package.$(get-date -f yyyy_MM_dd_hh_ss).cspkg"
     
    $containerState = Get-AzureStorageContainer -Name $containerName -ea 0
    if ($containerState -eq $null)
    {
        New-AzureStorageContainer -Name $containerName | out-null
    }
     
    Set-AzureStorageBlobContent -File $package -Container $containerName -Blob $blob -Force| Out-Null
    $blobState = Get-AzureStorageBlob -blob $blob -Container $containerName
 
    $blobState.ICloudBlob.uri.AbsoluteUri
}
 
Function Create-Deployment($package_url, $service, $slot, $config){
    $opstat = New-AzureDeployment -Slot $slot -Package $package_url -Configuration $config -ServiceName $service
}
  
Function Upgrade-Deployment($package_url, $service, $slot, $config){
    $setdeployment = Set-AzureDeployment -Upgrade -Slot $slot -Package $package_url -Configuration $config -ServiceName $service -Force
}
 
Function Check-Deployment($service, $slot){
    $completeDeployment = Get-AzureDeployment -ServiceName $service -Slot $slot
    $completeDeployment.deploymentid
}
 
try{
    Write-Host "Stargin Azure Deployment"
 
    "Upload the deployment package"
    $package_url = Upload-Package -package $package -containerName $containerName
    "Package uploaded to $package_url"
 
    $deployment = Get-AzureDeployment -ServiceName $service -Slot $slot -ErrorAction silentlycontinue 
 
 
    if ($deployment.Name -eq $null) {
        Write-Host "No deployment is detected. Creating a new deployment. "
        Create-Deployment -package_url $package_url -service $service -slot $slot -config $config
        Write-Host "New Deployment created"
 
    } else {
        Write-Host "Deployment exists in $service.  Upgrading deployment."
        Upgrade-Deployment -package_url $package_url -service $service -slot $slot -config $config
        Write-Host "Upgraded Deployment"
    }
 
    $deploymentid = Check-Deployment -service $service -slot $slot
    Write-Host "Deployed to $service with deployment id $deploymentid"
}
catch
{
	write-host "Caught an exception:" -ForegroundColor Red
    write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}