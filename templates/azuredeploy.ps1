param($Location, $ResourceGroupName, $TemplateFile, $TemplateParameterFile, $prefix, $slackURL)
$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "scripts\alertScript.csx" -Raw
. "../scripts/generatePass.ps1"

if (!$prefix) {$prefix = 'armeschool'}
if (!$ResourceGroupName.StartsWith("rg")) { $ResourceGroupName = "rg-"+$ResourceGroupName+"-"+$Location }
Write-Host "##[debug]Getting resource group"

Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction silentlycontinue
Write-Host $notPresent
if ($notPresent) { New-AzResourceGroup -Name $ResourceGroupName -Location $Location}

$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString Get-RandomPassword 8  -AsPlainText -Force
$slackURL = ConvertTo-SecureString $slackURL  -AsPlainText -Force

Write-Host "##[debug]Validating template"
$notValid=Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorVariable $notValid -ErrorAction SilentlyContinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
if ($notValid) {
    Write-Host $notValid.Message
    Write-Host "Template is not valid according to the validation procedure\n Use Get-AzLog -CorrelationId <correlationId> for more info"
    exit
}


Write-Host "##[debug]Deploying template"
New-AzResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $ResourceGroupName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript
