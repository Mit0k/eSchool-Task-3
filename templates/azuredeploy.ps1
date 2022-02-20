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


Write-Host "##[debug]Deploying template"
New-AzDeployment `
    -Name $deploymentName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript `
    -RgList $ResourceGroupNames -UrlList $templateUrlList
