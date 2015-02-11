function New-SDAzureWebsite
{
param
(
[String]$ApplicationName,
[String]$Location,
[String]$StorageAccountName,
[hashtable]$ConnectionStrings
[String]$AppInsightsKey
)

try{
Write-Verbose "Checking for a Windows Azure website: $ApplicationName, creating if does not exist"
#If the Application Type is a website, then create a new website if it doesn't exist
if (!(Get-AzureWebsite |where-object{$_.Name -eq $ApplicationName}))
{
Write-Verbose "Website named:  $ApplicationName does not exist creating website"
$website = New-AzureWebsite -Name $ApplicationName -Location $Location -Verbose
if (!$website) {throw "Error: Website was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureWebsite returned and try again."}
}
Write-Verbose "[Start] Adding settings to website: $ApplicationName"
# Configure app settings for storage account
#if we don't pass in an Application Insights Key don't set it 

#Get azure storage account access key



if (!($AppInsightsKey))
{
$appSettings = @{ `
    "StorageAccountName" = $storageAccountName; `
    "StorageAccountAccessKey" = $storage.AccessKey; `
	}
}
else{
$appSettings = @{ `
    "StorageAccountName" = $storageAccountName; `
    "StorageAccountAccessKey" = $storage.AccessKey; `
	"ApplicationInsights_InstrumentationKey" = $AppInsightsKey; `
	}
}


Write-Verbose "Adding connection strings and storage account name/key to the new $ApplicationName website."
# Add the connection string and storage account name/key to the website
Set-AzureWebsite -Name $ApplicationName -AppSettings $appSettings -ConnectionStrings $connectionStrings






Write-Verbose "[Finish] Adding settings to website: $ApplicationName"
Write-Verbose "[Finish] creating Windows Azure environment: $ApplicationName"
}
catch {
  "any other undefined errors"
  $error[0]
}


}