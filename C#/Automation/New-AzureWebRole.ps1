#Package needs to be .cspkg file or .zip
#config needs to be cscfg file
Function New-SDAzureRole{
Param(
      [string]$serviceName,
      [string]$containerName,
      [string]$config,
      [string]$package,
      [string]$slot="Production"
	  [String]$Location
	  )
 
 
Function Upload-Package($package, $containerName){
    $blob = "$serviceName.package.$(get-date -f yyyy_MM_dd_hh_ss).cspkg"
     
    $containerState = Get-AzureStorageContainer -Name $containerName -ea 0
    if ($containerState -eq $null)
    {
        New-AzureStorageContainer -Name $containerName | out-null
    }
     
    Set-AzureStorageBlobContent -File $package -Container $containerName -Blob $blob -Force| Out-Null
    $blobState = Get-AzureStorageBlob -blob $blob -Container $containerName
 
    $blobState.ICloudBlob.uri.AbsoluteUri
}
 
Function Create-Deployment($package_url, $serviceName, $slot, $config){
    $opstat = New-AzureDeployment -Slot $slot -Package $package_url -Configuration $config -ServiceName $serviceName
}
  
Function Upgrade-Deployment($package_url, $serviceName, $slot, $config){
    $setdeployment = Set-AzureDeployment -Upgrade -Slot $slot -Package $package_url -Configuration $config -ServiceName $serviceName -Force
}
 
Function Check-Deployment($serviceName, $slot){
    $completeDeployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
    $completeDeployment.deploymentid
}
 
try{
    Write-Host "Stargin Azure Deployment"
 
    "Upload the deployment package"
    $package_url = Upload-Package -package $package -containerName $containerName
    "Package uploaded to $package_url"
 
    $ServiceExist = Get-AzureService -ServiceName $ServiceName -ErrorAction silentlycontinue
	if (!($ServiceExist)){New-AzureService -ServiceName $ServiceName -Location $Location}
	$deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot -ErrorAction silentlycontinue 
 
 
    if ($deployment.Name -eq $null) {
        Write-Host "No deployment is detected. Creating a new deployment. "
		
        Create-Deployment -package_url $package_url -service $serviceName -slot $slot -config $config
        Write-Host "New Deployment created"
 
    } else {
        Write-Host "Deployment exists in $serviceName.  Upgrading deployment."
        Upgrade-Deployment -package_url $package_url -service $serviceName -slot $slot -config $config
        Write-Host "Upgraded Deployment"
    }
 
    $deploymentid = Check-Deployment -service $serviceName -slot $slot
    Write-Host "Deployed to $serviceName with deployment id $deploymentid"
}
catch
{
	write-host "Caught an exception:" -ForegroundColor Red
    write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}
}