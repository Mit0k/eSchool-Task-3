param($Location, $TemplateFile, $TemplateParameterFile, $prefix, $slackURL)
$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "scripts\alertScript.csx" -Raw
. "scripts\generatePass.ps1"
if (!$prefix) {$prefix = 'armeschool'}
Write-Host "##[debug]Getting resource group"

$rgCommonName= "rg-"+$prefix+"-common-base-"+$Location
$rgMetricsName="rg-"+$prefix+"-common-metrics-"+$Location
$rgWebAppName= "rg-"+$prefix+"-APP-"+$Location

$ResourceGroupNames = $rgCommonName,$rgMetricsName,$rgWebAppName
Write-Host "##[debug]$ResourceGroupNames"
Foreach ($rg in $ResourceGroupNames){
    Get-AzResourceGroup -Name $rg -ErrorVariable notPresent -ErrorAction silentlycontinue
    if ($notPresent) {
        New-AzResourceGroup -Name $rg -Location $Location
    }
}



$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString (Get-RandomPassword 8)  -AsPlainText -Force
$slackURL = ConvertTo-SecureString $slackURL  -AsPlainText -Force

Write-Host "##[debug]Validating template"
$notValid=Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
if ($notValid) {
    Write-Host $notValid.Message
    Write-Host "Template is not valid according to the validation procedure\n Use Get-AzLog -CorrelationId <correlationId> for more info"
    exit
}

Write-Host "##[debug]Deploying template"
New-AzDeployment `
    -Name $deploymentName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript
