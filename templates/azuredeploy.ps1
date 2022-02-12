###-----------------------------------------------------------
$Location='eastus'
$ResourceGroupName='fucker'
$DatabasePassword='Tester00__'
$TemplateFile='C:\Users\mitok\source\repos\ArmWebAppSDB\eschool-webappSDB\templates\azuredeploy.json'
$TemplateParameterFile='C:\Users\mitok\source\repos\ArmWebAppSDB\eschool-webappSDB\templates\azuredeploy.parameters.json'
$prefix='fucku'
$KvResourceGroupName='rg-secrets-eastus'
$keyvaultName = 'kv-secrests-eastus'
$KvLocation = 'East US'
###
###-------------------------------------------------------------
#param($Location, $ResourceGroupName, $DatabasePassword, $TemplateFile, $TemplateParameterFile, $prefix, $KvResourceGroupName)

if (!$prefix) {
    Write-Host 'Using default name prefix'
    $prefix = 'armgen'
}
if (!$KvResourceGroupName) {
    Write-Host 'Using default resource group for keyvault'
    $KvResourceGroupName = 'armgen'
}
if (!$KvLocation) {
    Write-Host 'Using default keyvault location'
    $KvLocation = $Location
}
if (!$keyvaultName) {
    Write-Host 'Using default keyvault name'
    $keyvaultName = 'kv-'+$prefix+$KvLocation
}
if (!$ResourceGroupName.StartsWith("rg")) {
    $ResourceGroupName = "rg-"+$ResourceGroupName+"-"+$Location
}

Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable $notPresent
if (!$notPresent)
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}


$notPresent=(Get-AzKeyVault -VaultName $keyvaultName)
if (!$notPresent){
    $InRemovedState=(Get-AzKeyVault -VaultName $keyvaultName -InRemovedState -Location $KvLocation) 
    if ($InRemovedState) {
        Write-Host "In removed state"
        exit
    }
    New-AzKeyVault -Name $keyvaultName -ResourceGroupName $KvResourceGroupName -Location $KvLocation
    $secretvalue = ConvertTo-SecureString (-join ((48..57) + (97..122) | Get-Random -Count 32 | % {[char]$_})) -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $keyvaultName -Name 'functionKey' -SecretValue $secretvalue
}
else{if (!$secret) {
        $secretvalue = ConvertTo-SecureString (-join ((48..57) + (97..122) | Get-Random -Count 32 | % {[char]$_})) -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $keyvaultName -Name 'functionKey' -SecretValue (ConvertTo-SecureString (-join ((48..57) + (97..122) | Get-Random -Count 32 | % {[char]$_})) -AsPlainText -Force)
}}

$secret = Get-AzKeyVaultSecret -VaultName $keyvaultName -Name 'functionKey' -AsPlainText
$secret = ConvertTo-SecureString $secret  -AsPlainText -Force

$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString $DatabasePassword  -AsPlainText -Force



$notValid = Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorVariable notValid -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
if ($notValid) {
    Write-Host $notValid.Message
    Write-Host "Template is not valid according to the validation procedure\n Use Get-AzLog -CorrelationId <correlationId> for more info"
    exit
}

New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Location $Location `
     -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile `
     -prefix $prefix  -databasePassword $databasePassword `
     -functionHostKey $secret -Force

$webappName=(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName).Outputs.webappName.value
$WebHost=(Get-AzWebApp -ResourceGroup $ResourceGroupName -Name $webappName).HostNames[0]
$ServerName=(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName).Outputs.serverName.value
$DbUsername=(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName).Outputs.dbUsername.value

Stop-AzWebApp -ResourceGroupName $ResourceGroupName -Name $webappName
$webapp = Get-AzWebApp -Name $webappName -ResourceGroupName $ResourceGroupName
$appset = $webapp.SiteConfig.AppSettings


$url = new-object Microsoft.Azure.Management.WebSites.Models.NameValuePair
$user = new-object Microsoft.Azure.Management.WebSites.Models.NameValuePair
$port = new-object Microsoft.Azure.Management.WebSites.Models.NameValuePair
$ssl = new-object Microsoft.Azure.Management.WebSites.Models.NameValuePair
$hostlink = new-object Microsoft.Azure.Management.WebSites.Models.NameValuePair
$profile = new-object Microsoft.Azure.Management.WebSites.Models.NameValuePair


$url.Name = "DATASOURCE_URL"
$url.Value = "jdbc:mysql://${ServerName}.mysql.database.azure.com:3306/eschool?useUnicode=true&characterEncoding=utf8&createDatabaseIfNotExist=true&autoReconnect=true&useSSL=true&enabledTLSProtocols=TLSv1.2"
$appset.Add($url)

$user.Name = "DATASOURCE_USERNAME"
$user.Value = "${DbUsername}@${ServerName}"
$appset.Add($user)

$port.Name = "SERVER_PORT"
$port.Value = "80"
$appset.Add($port)

$ssl.Name = "SSL_ENABLE"
$ssl.Value = "false"
$appset.Add($ssl)

$hostlink.Name = "ESCHOOL_APP_HOST"
$hostlink.Value = "${WebHost}"
$appset.Add($hostlink)
   
$newappset = @{}
$appset | ForEach-Object {
    $newappset[$_.Name] = $_.Value
}

$profile.Name = "SPRING_PROFILES_ACTIVE"
$profile.Value = "production"
$appset.Add($profile)


Set-AzWebApp -ResourceGroupName $ResourceGroupName -Name $webappName  -AppSettings $newappset -HttpLoggingEnabled $true
$webapp = Get-AzWebApp -Name $webappName -ResourceGroupName $ResourceGroupName

$webapp.SiteConfig.AppSettings
Write-Host "##vso[task.setvariable variable=webappName;isOutput=true]$webappName"
Write-Host "##vso[task.setvariable variable=groupName;isOutput=true]$ResourceGroupName"

