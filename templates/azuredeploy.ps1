param($Location, $ResourceGroupName, $DatabasePassword, $TemplateFile, $TemplateParameterFile, $prefix, $slackURL)

$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"

if (!$prefix) {
    Write-Host 'Using default name prefix'
    $prefix = 'armgen'
}

if (!$ResourceGroupName.StartsWith("rg")) {
    $ResourceGroupName = "rg-"+$ResourceGroupName+"-"+$Location
}

Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable $notPresent -ErrorAction silentlycontinue
if (!$notPresent)
{
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString $DatabasePassword  -AsPlainText -Force
$slackURL = ConvertTo-SecureString $slackURL  -AsPlainText -Force


$notValid=Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorVariable $notValid -ErrorAction silentlycontinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
if ($notValid) {
    Write-Host $notValid.Message
    Write-Host "Template is not valid according to the validation procedure\n Use Get-AzLog -CorrelationId <correlationId> for more info"
    exit
}

$alertScript = Get-Content -Path "templates\alertScript.csx" -Raw
$alertScript=$alertScript.replace('\\','\\')
$alertScript=$alertScript.replace('"','\"')
$alertScript=$alertScript.replace("`r`n",'\r\n')

New-AzResourceGroupDeployment -WhatIf --mode Incremental `
    -Name $deploymentName -ResourceGroupName $ResourceGroupName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript

$webappName=(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName).Outputs.webappName.value

Write-Host "##vso[task.setvariable variable=webappName;isOutput=true]$webappName"
Write-Host "##vso[task.setvariable variable=groupName;isOutput=true]$ResourceGroupName"

