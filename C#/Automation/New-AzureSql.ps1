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