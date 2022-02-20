param($Location, $TemplateFile, $TemplateParameterFile, $prefix, $slackURL,$templateUrlList)
Write-Host $templateUrlList
$templateUrlList = $templateUrlList.Split('')
$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "scripts\alertScript.csx" -Raw
. "scripts\generatePass.ps1"

if (!$prefix) {$prefix = 'armeschool'}
Write-Host "##[debug]Getting resource group"

$ResourceGroupNames = @()
$ResourceGroupNames += "rg-"+$prefix+"-common-base-"+$Location
$ResourceGroupNames +="rg-"+$prefix+"-common-metrics-"+$Location
$ResourceGroupNames += "rg-"+$prefix+"-APP-"+$Location

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
$notValid=Test-AzDeployment -ErrorVariable notValid -ErrorAction SilentlyContinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
if (!$notValid) {
    Write-Host $notValid.Code
    Write-Host $notValid.Message
    Write-Host $notValid.Details
    throw "Template is not valid according to the validation procedure\nTry to Use Get-AzLog -CorrelationId <correlationId> for more info"
}

Write-Host "##[debug]Deploying template"
New-AzDeployment `
    -DeploymentDebugLogLevel All `
    -Name $deploymentName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript `
    -RgList $ResourceGroupNames -UrlList $templateUrlList
