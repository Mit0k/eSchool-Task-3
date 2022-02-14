param($Location, $ResourceGroupName, $DatabasePassword, $TemplateFile, $TemplateParameterFile, $prefix, $slackURL)


$TemplateFile=".\azuredeploy.json"
$TemplateParameterFile=".\azuredeploy.parameters.json"

if (!$prefix) {
    Write-Host 'Using default name prefix'
    $prefix = 'armeschool'
}
Write-Host 1
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
Write-Host 3
$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DatabasePassword = ConvertTo-SecureString $DatabasePassword  -AsPlainText -Force
$slackURL = ConvertTo-SecureString $slackURL  -AsPlainText -Force
<<<<<<< HEAD
Write-Host "##[debug]Validating template"
$notValid=Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorVariable $notValid -ErrorAction SilentlyContinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location 5>&1 
=======


$notValid=Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -ErrorVariable $notValid -ErrorAction silentlycontinue -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile -Location $Location -Force 5>&1 
>>>>>>> dfc4364f5068c8b873d54d2586c7758128743f7a
if ($notValid) {
    Write-Host $notValid.Message
    Write-Host "Template is not valid according to the validation procedure\n Use Get-AzLog -CorrelationId <correlationId> for more info"
    exit
}
<<<<<<< HEAD
$alertScript = Get-Content -Path ".\alertScript.csx" -Raw
$alertScript=$alertScript.replace('\\','\\')
$alertScript=$alertScript.replace('"','\"')
$alertScript=$alertScript.replace("`r`n",'\r\n')
Write-Host "##[debug]Deploying template"
New-AzResourceGroupDeployment `
=======
Write-Host 4
$alertScript = Get-Content -Path "templates\alertScript.csx" -Raw
$alertScript=$alertScript.replace('\\','\\')
$alertScript=$alertScript.replace('"','\"')
$alertScript=$alertScript.replace("`r`n",'\r\n')
Write-Host 5
New-AzResourceGroupDeployment -Confirm:$false `
>>>>>>> dfc4364f5068c8b873d54d2586c7758128743f7a
    -Name $deploymentName -ResourceGroupName $ResourceGroupName -Location $Location `
    -TemplateFile $TemplateFile -TemplateParameterFile  $TemplateParameterFile `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript

$webappName=(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName).Outputs.webappName.value

Write-Host "##vso[task.setvariable variable=webappName;isOutput=true]$webappName"
Write-Host "##vso[task.setvariable variable=groupName;isOutput=true]$ResourceGroupName"

