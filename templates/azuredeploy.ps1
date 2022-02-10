param($Location, $ResourceGroupName, $DatabasePassword, $TemplateFile, $TemplateParameterFile, $prefix, $outputWebAppName)

if (!$prefix) {
    Write-Host 'Using default name prefix'
    $prefix = 'armgen'
}

if (!$ResourceGroupName.StartsWith("rg")) {
    $ResourceGroupName = "rg-"+$ResourceGroupName+"-"+$Location
}
Write-Host $prefix
$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString $DatabasePassword  -AsPlainText -Force

New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force
Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location

New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -Location $Location `
     -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -prefix $prefix  -databasePassword $databasePassword -Force

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

