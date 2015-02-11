Param(
    #The number of parameters is getting bloated#
    param(
    [String]$ApplicationName,           
    [String]$Location = "East US"
	[String]$StorageAccountName,
	[String]$ApplicationType
	[String]$SubscriptionName,
	[String]$sqlAppDatabaseName, 
	[String]$SqlDatabaseUserName,  
    [String]$SqlDatabasePassword,
	[String]$DBConfig,
	[String]$DBEdition,
	[String]$AppInsightsKey,
	[String]$CSProjPath,
	[String]$WebOutputDir,
	[String]$ServiceBusNamespace,
	[String]$ServiceBusQueueName,
	[String]$CSProjName,

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
if (!($StorageAccountName)){throw "You must pass in a storage account name"}
$storage = New-SDAzureStorage -Name $StorageAccountName -Location $Location
if (!$storage) {throw "Error: Storage account was not created. Terminating the script unsuccessfully. Fix the errors that New-SDAzureStorage function returned and try again."}

#Ensuring the subscription uses the newly created storage account
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccountName $storageAccountName

Write-Verbose "Creating a Windows Azure database server and databases if a database name variable is passed in"
# Create a SQL Azure database server, and database
if ($sqlAppDatabaseName){
$sql = New-SDAzureSQL `
    -AppDatabaseName $sqlAppDatabaseName `
    -UserName $SqlDatabaseUserName `
    -Password $SqlDatabasePassword `
    -FirewallRuleName $sqlDatabaseServerFirewallRuleName `
    -StartIPAddress $StartIPAddress `
    -EndIPAddress $EndIPAddress `
    -Location $Location
if (!$sql) {throw "Error: The database server or databases were not created. Terminating the script unsuccessfully. Failures occurred in New-AzureSql.ps1."}

$connectionStrings = ( `
    @{Name = $sqlAppDatabaseName; Type = "SQLAzure"; ConnectionString = $sql.AppDatabase.ConnectionString}
)
}

else
{ 
Write-Host "No SQL App Database Name was passed in, skipping the creation"
}
#Setup Connection Strings for Newly created database
# Configure connection strings for website to database



#Team City will pull down a repo from Git and put the entire contentes into a "working directory"  
#CSProjPath is passed in from Team City and is really the root directory 
I
Write-Verbose "The value of `$CSProjPath is:  $CSProjPath"

$ProjectFile = (Get-ChildItem -recurse $CSProjPath | Where-Object {$_.Name -eq $CSProjName}).FullName
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



#Creating Service Bus Name Space and Queue if it was passed in, other wise skip creation

if (($ServiceBusNamespace) -and ($ServiceBusQueueName))
{
New-SDAzureSBNameSpace $ServiceBusNamespace $ServiceBusQueueName
}
else 
{
Write-Verbose "Values for `$ServiceBusNamespace and `$ServiceBusQueueName were not passed in, skipping creation"
}
#  Going to be produced by MSBuild $CSPkgName,
#  Going to be produced by MSBuild $CSCnfgName

switch ($ApplicationType)
	{
	Website {New-SDAzureWebsite -ApplicationName $ApplicationName -Location $Location -StorageAccountName $StorageAccountName `
	-connectionStrings $connectionStrings -AppInsightsKey $AppInsightsKey}
	WebRole {New-SDAzureRole -ServiceName $ApplicationName -containerName $ApplicationName -config $CSCnfgName -package $CSPkgName `
	-slot "Production" -Location $Location}
	WorkerRole {New-SDAzureRole -ServiceName $ApplicationName -containerName $ApplicationName -config $CSCnfgName -package $CSPkgName `
	-slot "Production" -Location $Location}
	default {"No Application Type passed in, not running the creation scripts"}
	}



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



