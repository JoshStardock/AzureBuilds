    param(
    [String]$orleanspass,           
    [String]$apipass,
	[String]$statsmessagepumppass
	)
. .\New-SDAzureTachyonEnv.vars.ps1
<#
Import-Module .\New-SDAzureTachyon.psm1
$module2 = (Get-Module |Where-Object {$_.Name -eq 'New-SDAzureTachyon'})
Write-Host "The value of `$module2 is:  $module2"
#>
Write-Host "This section updates each hash table with the appropriate password for that application"
Write-Host "The applications list is predefined"
#This can be handled more dynamicaly if we do not care that all applications share a password.
Write-Host "The value of `$applications is:  "$applications
foreach ($app in $applications)
{
$findpass = $app.GetEnumerator()|Where-Object{$_.key -eq "ApplicationName"}
$findpass = $findpass.Value

if ($findpass -like "*orleans*")
{
$app.set_item("SqlDatabasePassword","$orleanspass")
Write-Host "DBPassword has been added from TeamCity"
}
elseif($findpass -like "*api*")
{
$app.set_item("sqlDatabasePassword","$apipass")
Write-Host "DBPassword has been added from TeamCity"
}
elseif($findpass -like "*statsmessagepump*")
{
$app.set_item("sqldatabasePassword","$statsmessagepumppass")
Write-Host "DBPassword has been added from TeamCity"
}
else
{
Write-Host "The value of `$Findpass is:  $findpass"
Write-Host "There was not an application that matched the value within `$findpass"
}
}
#Begin Building Environment
try
{
foreach ($app in $applications)
{
$CurrentAppBuild = $app.GetEnumerator()|Where-Object{$_.key -eq "ApplicationName"}
$CurrentAppBuild = $CurrentAppBuild.value
Write-Host "The current app being built is:  $CurrentAppBuild"
. .\New-SDAzureTachyonEnv.ps1 @app
}
}

catch {
  "any other undefined errors"
  $error[0]
}