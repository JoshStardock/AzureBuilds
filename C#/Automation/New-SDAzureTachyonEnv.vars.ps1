#Define a hash table and each 
$applications = @()
$TachyonApi = @{
"ApplicationName" = "joshtachyon-api-test";
"Location" = "East US";
"StorageAccountName" = "joshmtachyonprod";
"ApplicationType" = "WorkerRole";
"sqlAppDatabaseName" = "joshtachyon-core-test";
"SqlDatabaseUserName" = "dbuser";
"SqlDatabasePassword" = "P3ril0usF!Ght1814";
"dbconfig" = "NoChange";
"DBEdition" = "Web";
"AppInsightsKey" = "$Null";
"CloudServiceName" = "joshmtachyon-services-test";
"ServiceBusNamespace" = "joshmtachyon-test";
"ServiceBusQueueName" = "joshmtachyon-statsqueue-test";
"CSProjName" = "$Null";
"CSPkgName" = "$Null";
"CSCnfgName" = "$Null";
}

$TachyonOrleans = @{
"ApplicationName" = "joshtachyon-orleans-test";
"Location" = "East US";
"StorageAccountName" = "joshmtachyonprod";
"ApplicationType" = "WorkerRole";
"sqlAppDatabaseName" = "joshtachyon-core-test";
"SqlDatabaseUserName" = "dbuser";
"SqlDatabasePassword" = "P3ril0usF!Ght1814";
"dbconfig" = "NoChange";
"DBEdition" = "Web";
"AppInsightsKey"  = "$Null";
"CloudServiceName" = "joshmtachyon-services-test";
"ServiceBusNamespace" = "joshmtachyon-test";
"ServiceBusQueueName" = "joshmtachyon-statsqueue-test";
"CSProjName" = "$Null";
"CSPkgName" = "$Null";
"CSCnfgName" = "$Null";
}

$TachyonStatsMsgPump = @{
"ApplicationName" = "joshtachyon-statsmessagepump-test";
"Location" = "East US";
"StorageAccountName" = "joshmtachyonprod";
"ApplicationType" = "WorkerRole";
"sqlAppDatabaseName" = "joshtachyon-core-test";
"SqlDatabaseUserName" = "dbuser";
"SqlDatabasePassword" = "P3ril0usF!Ght1814";
"dbconfig" = "NoChange";
"DBEdition" = "Web";
"AppInsightsKey"  = "$Null";
"CloudServiceName" = "joshmtachyon-services-test";
"ServiceBusNamespace" = "joshmtachyon-test";
"ServiceBusQueueName" = "joshmtachyon-statsqueue-test";
"CSProjName" = "$Null";
"CSPkgName"  = "$Null";
"CSCnfgName" = "$Null";
}

$applications += $TachyonApi
$applications += $TachyonOrleans
$applications += $TachyonStatsMsgPump

<#
foreach ($app in $applications)
{
New-SDAzureTachyonEnv @app
}
#>

