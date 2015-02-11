Import-Module New-SDAzureTachyon.psm1
. .\New-SDAzureTachyonEnv.vars.ps1
#Begin Building Environment
try
{
foreach ($app in $applications)
{
New-SDAzureTachyonEnv @app
}
}

catch {
  "any other undefined errors"
  $error[0]
}