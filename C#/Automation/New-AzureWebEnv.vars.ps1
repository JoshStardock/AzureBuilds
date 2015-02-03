. .\New-RandomPass.ps1

$params = @{'name' = 'name';
'location' = 'location';
'SqlDatabaseUserName' = 'dbusername';
'SqlDatabasePassword' = New-RandomPass -MinPasswordLength 12 -MaxPasswordLength 15 -Count 1;
'slot' = 'staging';
}
