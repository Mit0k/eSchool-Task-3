###-----------------------------------------------------------
$Location='eastus'
$ResourceGroupName='jedi'
$DatabasePassword='Tester00__'
$TemplateFile='C:\Users\mitok\source\repos\ArmWebAppSDB\eschool-webappSDB\templates\azuredeploy.json'
$TemplateParameterFile='C:\Users\mitok\source\repos\ArmWebAppSDB\eschool-webappSDB\templates\azuredeploy.parameters.json'
$prefix='jedi'
$slackURL = "https://hooks.slack.com/services/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"
$TemplateFile=".\azuredeploy.json"
$TemplateParameterFile=".\azuredeploy.parameters.json"
###
###-------------------------------------------------------------
#param($Location, $ResourceGroupName, $DatabasePassword, $TemplateFile, $TemplateParameterFile, $prefix, $slackURL)
#$TemplateFile="templates\azuredeploy.json"
#$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "templates\alertScript.csx" -Raw

if (!$prefix) {
    Write-Host 'Using default name prefix'
    $prefix = 'armeschool'
}

if (!$ResourceGroupName.StartsWith("rg")) {
    $ResourceGroupName = "rg-"+$ResourceGroupName+"-"+$Location
}
Write-Host "##[debug]Getting resource group"
Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction silentlycontinue
Write-Host $notPresent
if ($notPresent)
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString $DatabasePassword  -AsPlainText -Force
$slackURL = ConvertTo-SecureString $slackURL  -AsPlainText -Force
Write-Host "##[debug]Validating template"
$notValid=Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorVariable $notValid -ErrorAction SilentlyContinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
if ($notValid) {
    Write-Host $notValid.Message
    Write-Host "Template is not valid according to the validation procedure\n Use Get-AzLog -CorrelationId <correlationId> for more info"
    exit
}

$alertScript=$alertScript.replace('\\','\\')
$alertScript=$alertScript.replace('"','\"')
$alertScript=$alertScript.replace("`r`n",'\r\n')
Write-Host "##[debug]Deploying template"
New-AzResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $ResourceGroupName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript

$webappName=(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName).Outputs.webappName.value

Write-Host "##vso[task.setvariable variable=webappName;isOutput=true]$webappName"
Write-Host "##vso[task.setvariable variable=groupName;isOutput=true]$ResourceGroupName"

