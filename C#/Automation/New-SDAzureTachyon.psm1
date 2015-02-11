Function New-SDAzureSBNameSpace{
[CmdletBinding(PositionalBinding=$True)]
Param(
	[Parameter(Mandatory = $true)]
    #[ValidatePattern("^[a-z0-9]*$")]
    [String]$Namespace,                                      # required    needs to be alphanumeric
    [Parameter(Mandatory = $true)]
    #[ValidatePattern("^[a-z0-9]*$")]
    [String]$Path,                                           # required    needs to be alphanumeric    
    [Int]$AutoDeleteOnIdle = -1,                             # optional    default to -1
    [Int]$DefaultMessageTimeToLive = -1,                     # optional    default to -1
    [Int]$DuplicateDetectionHistoryTimeWindow = 10,          # optional    default to 10
    [Bool]$EnableBatchedOperations = $True,                  # optional    default to true
    [Bool]$EnableDeadLetteringOnMessageExpiration = $False,  # optional    default to false
    [Bool]$EnableExpress = $False,                           # optional    default to false
    [Bool]$EnablePartitioning = $False,                      # optional    default to false
    [String]$ForwardDeadLetteredMessagesTo = $Null,          # optional    default to null
    [String]$ForwardTo = $Null,                              # optional    default to null
    [Bool]$IsAnonymousAccessible = $False,                   # optional    default to false
    [Int]$LockDuration = 30,                                 # optional    default to 30
    [Int]$MaxDeliveryCount = 10,                             # optional    default to 10
    [Int]$MaxSizeInMegabytes = 1024,                         # optional    default to 1024
    [Bool]$RequiresDuplicateDetection = $False,              # optional    default to false
    [Bool]$RequiresSession = $False,                         # optional    default to false
    [Bool]$SupportOrdering = $True,                          # optional    default to true
    [String]$UserMetadata = $Null,                           # optional    default to null
    [Bool]$CreateACSNamespace = $False,                      # optional    default to $false
    [String]$Location = "East US"                        # optional    default to "West Europe"
    )
	
try
{
# Set the output level to verbose and make the script stop on error
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"


# WARNING: Make sure to reference the latest version of the \Microsoft.ServiceBus.dll
Write-Output "Adding the Microsoft.ServiceBus.dll assembly to the script..."
Add-Type -Path "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Compute\Microsoft.ServiceBus.dll"
Write-Output "The Microsoft.ServiceBus.dll assembly has been successfully added to the script."

# Mark the start time of the script execution
$startTime = Get-Date

# Create Azure Service Bus namespace
$CurrentNamespace = Get-AzureSBNamespace -Name $Namespace


# Check if the namespace already exists or needs to be created
if ($CurrentNamespace)
{
    Write-Output "The namespace $Namespace already exists in the $($CurrentNamespace.Region) region skipping creation" 
}
else
{
    Write-Host "The [$Namespace] namespace does not exist."
    Write-Output "Creating the [$Namespace] namespace in the [$Location] region..."
    New-AzureSBNamespace -Name $Namespace -Location $Location -CreateACSNamespace $CreateACSNamespace -NamespaceType Messaging
    $CurrentNamespace = Get-AzureSBNamespace -Name $Namespace
    Write-Host "The [$Namespace] namespace in the [$Location] region has been successfully created."
}

# Create the NamespaceManager object to create the queue
Write-Host "Creating a NamespaceManager object for the [$Namespace] namespace..."
$NamespaceManager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($CurrentNamespace.ConnectionString);
Write-Host "NamespaceManager object for the [$Namespace] namespace has been successfully created."

# Check if the queue already exists
if ($NamespaceManager.QueueExists($Path))
{
    Write-Output "The [$Path] queue already exists in the [$Namespace] namespace skipping creation." 
}
else
{
    Write-Output "Creating the [$Path] queue in the [$Namespace] namespace..."
    $QueueDescription = New-Object -TypeName Microsoft.ServiceBus.Messaging.QueueDescription -ArgumentList $Path
    if ($AutoDeleteOnIdle -ge 5)
    {
        $QueueDescription.AutoDeleteOnIdle = [System.TimeSpan]::FromMinutes($AutoDeleteOnIdle)
    }
    if ($DefaultMessageTimeToLive -gt 0)
    {
        $QueueDescription.DefaultMessageTimeToLive = [System.TimeSpan]::FromMinutes($DefaultMessageTimeToLive)
    }
    if ($DefaultMessageTimeToLive -gt 0)
    {
        $QueueDescription.DuplicateDetectionHistoryTimeWindow = [System.TimeSpan]::FromMinutes($DuplicateDetectionHistoryTimeWindow)
    }
    $QueueDescription.EnableBatchedOperations = $EnableBatchedOperations
    $QueueDescription.EnableDeadLetteringOnMessageExpiration = $EnableDeadLetteringOnMessageExpiration
    $QueueDescription.EnableExpress = $EnableExpress
    $QueueDescription.EnablePartitioning = $EnablePartitioning
    $QueueDescription.ForwardDeadLetteredMessagesTo = $ForwardDeadLetteredMessagesTo
    $QueueDescription.ForwardTo = $ForwardTo
    $QueueDescription.IsAnonymousAccessible = $IsAnonymousAccessible
    if ($LockDuration -gt 0)
    {
        $QueueDescription.LockDuration = [System.TimeSpan]::FromSeconds($LockDuration)
    }
    $QueueDescription.MaxDeliveryCount = $MaxDeliveryCount
    $QueueDescription.MaxSizeInMegabytes = $MaxSizeInMegabytes
    $QueueDescription.RequiresDuplicateDetection = $RequiresDuplicateDetection
    $QueueDescription.RequiresSession = $RequiresSession
    if ($EnablePartitioning)
    {
        $QueueDescription.SupportOrdering = $False
    }
    else
    {
        $QueueDescription.SupportOrdering = $SupportOrdering
    }
    $QueueDescription.UserMetadata = $UserMetadata
    $NamespaceManager.CreateQueue($QueueDescription);
    Write-Host "The [$Path] queue in the [$Namespace] namespace has been successfully created."
}

# Mark the finish time of the script execution
$finishTime = Get-Date

# Output the time consumed in seconds
$TotalTime = ($finishTime - $startTime).TotalSeconds
Write-Output "The script completed in $TotalTime seconds."
}
catch
{
	write-host "Caught an exception:" -ForegroundColor Red
    write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}
}


#Package needs to be .cspkg file or .zip
#config needs to be cscfg file
Function New-SDAzureRole{
Param(
      [string]$serviceName,
      [string]$containerName,
      [string]$config,
      [string]$package,
      [string]$slot="Production",
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

Function New-SDAzureStorage
{

[CmdletBinding(PositionalBinding=$False)]
Param(
    [Parameter(Mandatory = $true)]
    [String]$Name,    
    [String]$Location = "East US"
)

$Name = $Name.ToLower()

# Create a new storage account
Write-Verbose "[Start] creating $Name storage account $Location location"
if (!(Get-AzureStorageAccount|where-object {$_.storageAccountName -eq $Name -and $_.Location -eq $Location}))
{
	$storageAcct = New-AzureStorageAccount -StorageAccountName $Name -Location $Location -Verbose
		if ($storageAcct)
		{
			Write-Verbose "[Finish] creating $Name storage account in $Location location"
		}	
		else
		{
			throw "Failed to create a Windows Azure storage account. Failure in New-AzureStorage.ps1"
		}

	# Get the access key of the storage account
	$key = Get-AzureStorageKey -StorageAccountName $Name
	if (!$key) {throw "Failed to get storage key for $Name storage account. Failure in Get-AzureStorageKey in New-AzureStorage.ps1"}
	$primaryKey = $key.Primary

	# Generate the connection string of the storage account
	$connectionString = "BlobEndpoint=http://$Name.blob.core.windows.net/;QueueEndpoint=http://$Name.queue.core.windows.net/;TableEndpoint=http://$Name.table.core.windows.net/;AccountName=$Name;AccountKey=$primaryKey"
	Return @{AccountName = $Name; AccessKey = $primaryKey; ConnectionString = $connectionString}
}
else
{
# Get the access key of the storage account
	$key = Get-AzureStorageKey -StorageAccountName $Name
	if (!$key) {throw "Failed to get storage key for $Name storage account. Failure in Get-AzureStorageKey in New-AzureStorage.ps1"}
	$primaryKey = $key.Primary

	# Generate the connection string of the storage account
	$connectionString = "BlobEndpoint=http://$Name.blob.core.windows.net/;QueueEndpoint=http://$Name.queue.core.windows.net/;TableEndpoint=http://$Name.table.core.windows.net/;AccountName=$Name;AccountKey=$primaryKey"
	Return @{AccountName = $Name; AccessKey = $primaryKey; ConnectionString = $connectionString}
}

}


Function New-SDAzureTachyonEnv
{

Param(
    #The number of parameters is getting bloated#
    [String]$ApplicationName,           
    [String]$Location = "East US",
	[String]$sqlAppDatabaseName, 
	[String]$StorageAccountName, 	
    [String]$SqlDatabaseUserName,  
    [String]$SqlDatabasePassword,
	[String]$SubscriptionName,
	[String]$AppInsightsKey,
	[String]$CSProjPath, 
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

Function New-SDAzureSQL {
[CmdletBinding(PositionalBinding=$True)]

Param
      (
        [parameter(Mandatory=$False)]
        [String] $AppDatabaseName = "appdb",

        [parameter(Mandatory=$False)]
        [String] $UserName = "dbuser",

        # Required
        [parameter(Mandatory=$True)]
        [String] $Password,
        
        [parameter(Mandatory=$False)]
        [String] $FirewallRuleName = "WebsiteRule",
        
        [parameter(Mandatory=$False)]
        [String] $StartIPAddress,
        
        [parameter(Mandatory=$False)]
        [String]$EndIPAddress,
        
		[parameter(Mandatory=$False)]
        [String]$DBConfig,
		
        [parameter(Mandatory=$False)]
        [String]$Location = "West US"
		
      )


# Begin - Helper functions --------------------------------------------------------------------------------------------------------------------------

# Create firewall rule for the website using Windows Azure REST API and Set Firewall Rule
function New-FirewallRuleForWebsite
{
    Param
          (
             [parameter(Mandatory=$True)]
             [String]
             $FirewallRuleName,

             [parameter(Mandatory=$True)]
             [String]
             $DatabaseServerName
          )
          
    Write-Verbose "[start] Creating a new firewall rule $FirewallRuleName for the website in database server $DatabaseServerName."
    
    $s = Get-AzureSubscription -Current
    $subscriptionID = $s.SubscriptionId
    $thumbprint = $s.Certificate.Thumbprint
    if (!($subscriptionID -and $thumbprint)) {throw "Error: Cannot get Azure subscription ID and thumbprint. Failed in New-FirewallRuleForWebsite in New-AzureSql.ps1"}

    [string]$queryString = "https://management.database.windows.net:8443/$subscriptionID/servers/$DatabaseServerName/firewallrules/$FirewallRuleName" + '?op=AutoDetectClientIP'
    [string]$contenttype = "application/xml;charset=utf-8"
    $headers = @{"x-ms-version" = "1.0"}

    Write-Verbose "Calling 'Set Firewall Rule' Azure SQL REST API"
    [xml]$responseXml = $(Invoke-RestMethod -Method POST -Uri $queryString -CertificateThumbprint $thumbprint -Headers $headers -ContentType $contenttype -Verbose).Remove(0,1)
    if(!$responseXml) {throw "Error: Initial firewall rule was not created. Failed in New-FirewallRuleForWebsite in New-AzureSql.ps1"}
    
    $rule = Get-AzureSqlDatabaseServerFirewallRule -ServerName $DatabaseServerName -RuleName $FirewallRuleName
    if(!$rule) {throw "Error: Cannot get initial firewall rule. Failed in New-FirewallRuleForWebsite in New-AzureSql.ps1"}

    #Create the start and end IP addresses by substituting 0 and 255
    $ipInRule = $rule.StartIpAddress
    $split = $ipInRule.split(".")
    $StartIP = ($split[0..2] -join "."), 0   -join "."
    $EndIP =   ($split[0..2] -join "."), 255 -join "."
        
    Write-Verbose "Editing firewall rule to add IP address range: $StartIP - $EndIP"
    $newrule = Set-AzureSqlDatabaseServerFirewallRule -ServerName $DatabaseServerName -RuleName $FirewallRuleName -StartIpAddress $StartIP -EndIpAddress $EndIP
    if (!$newrule) {throw "Error: Cannot add start and end IP addresses to website firewall rule. Failed in New-FirewallRuleForWebsite in New-AzureSql.ps1"}
    Write-Verbose "[finish] Created firewall rule $FirewallRuleName for IP Address $ipAddressinRule"

    return $newrule
}

# Create a PSCrendential object from plain text password.
# The PS Credential object will be used to create a database context, which will be used to create database.
Function New-PSCredentialFromPlainText
{
    Param(
        [String]$UserName,
        [String]$Password
    )

    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

    Return New-Object System.Management.Automation.PSCredential($UserName, $securePassword)
}

# Generate connection string of a given SQL Azure database
Function Get-SQLAzureDatabaseConnectionString
{
    Param(
        [String]$DatabaseServerName,
        [String]$DatabaseName,
        [String]$UserName,
        [String]$Password
    )

    Return "Server=tcp:$DatabaseServerName.database.windows.net,1433;Database=$DatabaseName;User ID=$UserName@$DatabaseServerName;Password=$Password;Trusted_Connection=False;Encrypt=True;Connection Timeout=30;"
}


# End - Helper functions --------------------------------------------------------------------------------------------------------------------------

# Begin - Actual script ---------------------------------------------------------------------------------------------------------------------------

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
#Testing for the existence of a Azure SQL Server.  If there is more than 1 already in existence we are going to exit the script and throw 
#an error.  If there is only 1 Azure SQL Server in the subscription we will use it, if there is not one we create it

if (((Get-AzureSqlDatabaseServer).count) -gt 1){throw "There is more than one Azure SQL Database Servers in this subscription, this breaks the build process.  Please contact DevOps or Remove the additional Azure SQL Database Server"}
if (!(Get-AzureSqlDatabaseServer))
{
Write-Verbose "[Start] creating SQL Azure database server in $Location location with username $UserName and password $Password"
$databaseServer = New-AzureSqlDatabaseServer -AdministratorLogin $UserName -AdministratorLoginPassword $Password -Location $Location
if (!$databaseServer) {throw "Did not create database server. Failure in New-AzureSqlDatabaseServer in New-AzureSql.ps1"}
$databaseServerName = $databaseServer.ServerName
Write-Verbose "[Finish] creating SQL Azure database server $databaseServerName in location $Location with username $UserName and password $Password"
}
else
{
Write-Verbose "[Start] setting databases server variables since a server already exist on the account"
$databaseServer = Get-AzureSqlDatabaseServer
$databaseServerName = $databaseServer.ServerName
Write-Verbose "[Finish] Finished setting database server variables"
}
# Create firewall rules
#
Write-Verbose "[Start] creating firewall rule AllowAllAzureIP in database server $databaseServerName for IP addresses 0.0.0.0 - 0.0.0.0"
if (!(Get-AzureSqlDatabaseServerFirewallRule -ServerName $databaseServerName -RuleName "AllowAllAzureIP"))
{
$rule1 = New-AzureSqlDatabaseServerFirewallRule -AllowAllAzureServices -ServerName $databaseServerName -RuleName "AllowAllAzureIP" -Verbose
if (!$rule1) {throw "Failed to create AllowAllAzureIP firewall rule. Failure in New-AzureSql.ps1"}
Write-Verbose "[Finish] creating AllowAllAzureIP firewall rule in database server $databaseServerName for IP addresses 0.0.0.0 - 0.0.0.0"
}

else
{
Write-Host "Rule named AllowAllAzureIP already exist skipping creation"
}
<###########
#Need to determine how to handle databases:
3 scenarios
1.  NewDB (want to backup before doing any changes, throw error if db with name already exist...may not need to backup in prodution since backups are baked in with the standard tier will discuss with Tim Thursday)
2.  Copy Existing (may be able to pass in date, if db exist in subscription backup first)
3.  Update existing (backup first)
4.  NoChange
We will use $DBConfig as a parameter and run a switch statement
switch ($DBConfig)
{
Newdb {New-SDAzureDB}
Copy {Copy-SDAzureDB}
Update {Update-SDAzureDB}
default {No change to the existing database}
}
##########>

# Create a database context which includes the server name and credential
# These are all local operations. No API call to Windows Azure
$credential = New-PSCredentialFromPlainText -UserName $UserName -Password $Password
if (!$credential) {throw "Failed to create secure credentials. Failure in New-PSCredentialFromPlainText function in New-AzureSql.ps1"}

#This will need to run every time I cannot get an existing credential
$context = New-AzureSqlDatabaseServerContext -ServerName $databaseServerName -Credential $credential
if (!$context) {throw "Failed to create db server context for $databaseServerName. Failure in call to New-AzureSqlDatabaseServerContext in New-AzureSql.ps1"}

# Use the database context to create app database
Write-Verbose "[Start] creating database  $AppDatabaseName in database server $databaseServerName if it doesn't exist"
$appdb = Get-AzureSqlDatabase -ConnectionContext $context -DatabaseName $AppDatabaseName  -Verbose -ErrorAction SilentlyContinue
if(!($appdb))
{
Write-Verbose "No Azure Sql database with the name:  $AppDatabaseName, creating a new database"
if(!($DBEdition)){$DBEdition = "Web"}
Write-Verbose "If a edition to use for the database is not passed it will default to Web"
$appdb = New-AzureSqlDatabase -ConnectionContext $context -DatabaseName $AppDatabaseName -Edition $DBEdition -Verbose
if (!$appdb) {throw "Failed to create $AppDatabaseName application database. Failure in New-AzureSqlDatabase in New-AzureSql.ps1"}
Write-Verbose "[Finish] creating database $AppDatabaseName in database server $databaseServerName"
}


Write-Verbose "Creating database connection string for $appDatabaseName in database server $databaseServerName"
$appDatabaseConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $databaseServerName -DatabaseName $AppDatabaseName -UserName $UserName -Password $Password
if (!$appDatabaseConnectionString) {throw "Failed to create application database connection string for $AppDatabaseName. Failure in Get-SQLAzureDatabaseConnectionString function in New-AzureSql.ps1"}

Write-Verbose "Creating hash table to return..."
Return @{ `
    Server = $databaseServerName; UserName = $UserName; Password = $Password; `
    AppDatabase = @{Name = $AppDatabaseName; ConnectionString = $appDatabaseConnectionString}; `
    
}

# End - Actual script -----------------------------------------------------------------------------------------------------------------------------
}

function New-SDAzureWebsite
{
param
(
[String]$ApplicationName,
[String]$Location,
[String]$StorageAccountName,
[hashtable]$ConnectionStrings,
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
Export-ModuleMember -Function New-SDAzureSBNameSpace, New-SDAzureRole, New-SDAzureStorage, New-SDAzureTachyonEnv, New-SDAzureSQL, ` New-SDAzureWebsite
