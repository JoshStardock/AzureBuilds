<#$suffix:  "-test"
$DBName = "joshmtachyon-core-test"
$WorkerRoleName = "joshmtachyon-orleans-test"
$WebSiteName = "joshmtachyon-api-test"
$CloudServiceName = "joshmtachyon-services-test"
$StorageAccountName = "joshmtachyonprod"
$ServiceBusNamespace = "joshmtachyon-test"
$ServiceBusQueueName = "joshmtachyon-statsqueue-test"
#>


Param(
    #The number of parameters is getting bloated#
    [String]$WebsitesName            
    [String]$Location = "East US"
	[String]$sqlAppDatabaseName, 
	[String]$StorageAccountName, 	
    [String]$SqlDatabaseUserName,  
    [String]$SqlDatabasePassword,
	[String]$SubscriptionName,
	[String]$AppInsightsKey,
	[String]$CSProjPath,
	[String]$WebOutputDir,
	[String]$DBEdition,
	[String]$ServiceBusNamespace = "joshmtachyon-test"
	[String]$ServiceBusQueueName = "joshmtachyon-statsqueue-test"
	[String]$CSProjName = "Tachyon.Api.csproj"
	[String]$EnvType
	[hashtable]$WorkerRoles
    )

# Begin - Helper functions -------------------------------------------------------------------------------------------------------------------------
function Get-MissingFiles
{
    $Path = Split-Path $MyInvocation.PSCommandPath
    $files = dir $Path | foreach {$_.Name}
    $required= 'New-AzureSql.ps1',
               'New-AzureStorage.ps1',
               'New-AzureWebsiteEnv.ps1'

    foreach ($r in $required)
    {            
        if ($r -notin $files)
        {
            [PSCustomObject]@{"Name"=$r; "Error"="Missing"}
        }
    }
}


# End - Helper functions -----------------------------------------------------------------------------------------------------------------------------


# Begin - Actual script -----------------------------------------------------------------------------------------------------------------------------
try{
# Set the output level to verbose and make the script stop on error
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Get the time that script execution starts
$startTime = Get-Date
Write-Verbose "Checking for required files."
$missingFiles = Get-MissingFiles
if ($missingFiles) {$missingFiles; throw "Required files missing from WebSite subdirectory. Download and upzip the package and try again."}

# Running Get-AzureWebsite only to verify that Azure credentials in the PS session have not expired (expire 12 hours)
# If the credentials are expired, cmdlet throws a terminating error that stops the script.
Write-Verbose "Verifying that Windows Azure credentials in the Windows PowerShell session have not expired."
Get-AzureWebsite | Out-Null

Write-Host "The value of `$WebsiteName is $WebsiteName"

Write-Verbose "[Start] creating Windows Azure website environment: $WebsiteName"
# Get the directory of the current script
$scriptPath = Split-Path -parent $PSCommandPath

# Define the names of website, storage account, SQL Azure database and SQL Azure database server firewall rule
$WebsiteName = $WebsiteName.ToLower()
if (!($sqlAppDatabaseName))
{
$sqlAppDatabaseName = $WebsiteName + "db"
}

if (!($StorageAccountName))
{
$storageAccountName = $WebsiteName + "storage"
}
$storageAccountName = $storageAccountName.ToLower()
$sqlDatabaseServerFirewallRuleName = $WebsiteName + "rule"


Write-Verbose "Creating a Windows Azure storage account: $storageAccountName"
# Create a new storage account if it doesn't exist
$storage = & "$scriptPath\New-AzureStorage.ps1" -Name $storageAccountName -Location $Location
if (!$storage) {throw "Error: Storage account was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureStorage.ps1 script returned and try again."}

#Ensuring the subscription uses the newly created storage account
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccountName




Write-Verbose "Checking for a Windows Azure website: $WebsiteName, creating if does not exist"
# Create a new website if it doesn't exist

if (!(Get-AzureWebsite |where-object{$_.Name -eq $WebsiteName}))
{
Write-Verbose "Website named:  $WebsiteName does not exist creating website"
$website = New-AzureWebsite -Name $WebsiteName -Location $Location -Verbose
if (!$website) {throw "Error: Website was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureWebsite returned and try again."}
}
else
{
$website = Get-AzureWebsite -Name $WebsiteName -Verbose
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

Write-Verbose "[Start] Adding settings to website: $WebsiteName"
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

Write-Verbose "Adding connection strings and storage account name/key to the new $WebsiteName website."
# Add the connection string and storage account name/key to the website
$error.clear()
Set-AzureWebsite -Name $WebsiteName -AppSettings $appSettings -ConnectionStrings $connectionStrings




if ($error) {throw "Error: Call to Set-AzureWebsite with database connection strings failed."}

Write-Verbose "[Finish] Adding settings to website: $WebsiteName"
Write-Verbose "[Finish] creating Windows Azure environment: $WebsiteName"

############
#Creating Cloud Service if it doesn't exist
############

# Run MSBuild to publish the project
Write-Verbose "The value of `$CSProjPath is:  $CSProjPath"

$ProjectFile = (Get-ChildItem  -recurse $CSProjPath | Where-Object {$_.Name -eq $CSProjName}).FullName
Write-Verbose "The value of `$ProjectFile is:  $ProjectFile"
Write-Verbose "Make Sure that the `$WebOutputDir exist, if it doesn't it will be created.  It has a value of:  $WebOutputDir"
if(!(Test-Path $WebOutputDir)){New-Item -ItemType directory -Path $WebOutputDir -Force}


& "$env:windir\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" $ProjectFile `
/p:Configuration=Release `
/p:DeployOnBuild=True `
/p:DeployTarget=Package `
/p:OutputPath=$WebOutputDir `
/p:DeployIisAppPath=tachyon-api-$envType `



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


