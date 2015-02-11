﻿<#$suffix:  "-test"
$DBName = "joshmtachyon-core-test"
$WorkerRoleName = "joshmtachyon-orleans-test"
$ApplicationName = "joshmtachyon-api-test"
$CloudServiceName = "joshmtachyon-services-test"
$StorageAccountName = "joshmtachyonprod"
$ServiceBusNamespace = "joshmtachyon-test"
$ServiceBusQueueName = "joshmtachyon-statsqueue-test"
#>
Function New-SDAzureTachyonEnv
{

Param(
    #The number of parameters is getting bloated#
    [String]$ApplicationName,           
    [String]$Location = "East US"
	[String]$sqlAppDatabaseName, 
	[String]$StorageAccountName, 	
    [String]$SqlDatabaseUserName,  
    [String]$SqlDatabasePassword,
	[String]$SubscriptionName,
	[String]$AppInsightsKey,
	[String]$CSProjPath, #From Team City
	[String]$WebOutputDir,
	[String]$DBEdition,
	[String]$ServiceBusNamespace,
	[String]$ServiceBusQueueName,
	[String]$CSProjName	
    )

# Begin - Actual script -----------------------------------------------------------------------------------------------------------------------------
try{
# Set the output level to verbose and make the script stop on error
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Get the time that script execution starts
$startTime = Get-Date
Write-Verbose "Checking for required files."

# Running Get-AzureWebsite only to verify that Azure credentials in the PS session have not expired (expire 12 hours)
# If the credentials are expired, cmdlet throws a terminating error that stops the script.
Write-Verbose "Verifying that Windows Azure credentials in the Windows PowerShell session have not expired."
Get-AzureWebsite | Out-Null

Write-Host "The value of `$ApplicationName is $ApplicationName"

Write-Verbose "[Start] creating Windows Azure website environment: $ApplicationName"
# Get the directory of the current script
$scriptPath = Split-Path -parent $PSCommandPath


$sqlDatabaseServerFirewallRuleName = $ApplicationName + "rule"


Write-Verbose "Creating a Windows Azure storage account: $storageAccountName"
# Create a new storage account if it doesn't exist
#Moving to function calls to avoid scoping issues
#$storage = New-SDAzureStorage -Name $StorageAccountName -Location $Location
$storage = & "$scriptPath\New-AzureStorage.ps1" -Name $StorageAccountName -Location $Location
if (!$storage) {throw "Error: Storage account was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureStorage.ps1 script returned and try again."}

#Ensuring the subscription uses the newly created storage account
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccountName




Write-Verbose "Checking for a Windows Azure website: $ApplicationName, creating if does not exist"
#If the Application Type is a website, then create a new website if it doesn't exist

if (!(Get-AzureWebsite |where-object{$_.Name -eq $ApplicationName}))
{
Write-Verbose "Website named:  $ApplicationName does not exist creating website"
$website = New-AzureWebsite -Name $ApplicationName -Location $Location -Verbose
if (!$website) {throw "Error: Website was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureWebsite returned and try again."}
}
else
{
$website = Get-AzureWebsite -Name $ApplicationName -Verbose
}




Write-Verbose "Creating a Windows Azure database server and databases"
# Create a SQL Azure database server, and database
$sql = & "$scriptPath\New-AzureSql.ps1" `
    -AppDatabaseName $sqlAppDatabaseName `
    -UserName $SqlDatabaseUserName `
    -Password $SqlDatabasePassword `
    -FirewallRuleName $sqlDatabaseServerFirewallRuleName `
    -StartIPAddress $StartIPAddress `
    -EndIPAddress $EndIPAddress `
    -Location $Location
if (!$sql) {throw "Error: The database server or databases were not created. Terminating the script unsuccessfully. Failures occurred in New-AzureSql.ps1."}

Write-Verbose "[Start] Adding settings to website: $ApplicationName"
# Configure app settings for storage account

#if we don't pass in an Application Insights Key don't set it 
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
# Configure connection strings for appdb and
$connectionStrings = ( `
    @{Name = $sqlAppDatabaseName; Type = "SQLAzure"; ConnectionString = $sql.AppDatabase.ConnectionString}
)

Write-Verbose "Adding connection strings and storage account name/key to the new $ApplicationName website."
# Add the connection string and storage account name/key to the website
$error.clear()
Set-AzureWebsite -Name $ApplicationName -AppSettings $appSettings -ConnectionStrings $connectionStrings




if ($error) {throw "Error: Call to Set-AzureWebsite with database connection strings failed."}

Write-Verbose "[Finish] Adding settings to website: $ApplicationName"
Write-Verbose "[Finish] creating Windows Azure environment: $ApplicationName"

############
#Creating Cloud Service if it doesn't exist
############

# Run MSBuild to publish the project
Write-Verbose "The value of `$CSProjPath is:  $CSProjPath"

$ProjectFile = (Get-ChildItem  -recurse $CSProjPath | Where-Object {$_.Name -eq $CSProjName}).FullName
Write-Verbose "The value of `$ProjectFile is:  $ProjectFile"
Write-Verbose "Make Sure that the `$WebOutputDir exist, if it doesn't it will be created.  It has a value of:  $WebOutputDir"
if(!(Test-Path $WebOutputDir)){New-Item -ItemType directory -Path $WebOutputDir -Force}
if (!(Test-Path $WebOutputDir\$ApplicationName)){New-Item -ItemType directory -Path $WebOutputDir\$ApplicationName}

& "$env:windir\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" $ProjectFile `
/p:Configuration=Release `
/p:DeployOnBuild=True `
/p:DeployTarget=Package `
/p:OutputPath=$WebOutputDir\$ApplicationName `
/p:DeployIisAppPath=$ApplicationName `



. .\New-AzureSDNameSpace.ps1
New-SDNameSpace $ServiceBusNamespace $ServiceBusQueueName

. .\NewAzureWebRole  `
      -serviceName `
      -containerName `
      -config `
      -package `
      -slot="Production" `
	  -Location


Write-Verbose "Script is complete."
# Mark the finish time of the script execution
$finishTime = Get-Date
# Output the time consumed in seconds
$TotalTime = ($finishTime - $startTime).TotalSeconds
Write-Output "Total time used (seconds): $TotalTime"

# End - Actual script ------------------------------------------------------------------------------------------------------------------------------- -

}

catch {
  "any other undefined errors"
  $error[0]
}
}


