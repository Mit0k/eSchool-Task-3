param($Location, $prefix, $slackURL)
$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "scripts\alertScript.csx" -Raw
. "scripts\generatePass.ps1"

if (!$prefix) {$prefix = 'armeschool'}
$objectID= Get-AzContext
$objectID=$objectID.Account.Id
$objectID = ConvertTo-SecureString $objectID  -AsPlainText -Force
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

Write-Host "##[section]Deploying template"
Write-Host "##[debug][Template spec]::Create"
New-AzTemplateSpec `
    -Name webAppSpec `
    -Version "1.0.0.0" `
    -ResourceGroupName $ResourceGroupNames[0] `
    -Location $Location `
    -TemplateFile "templates\azuredeploy.json" `
    -Force -Confirm:$false `
    -ErrorVariable notValobjectID -ErrorAction SilentlyContinue
Write-Host $notValobjectID
Write-Host $notValobjectID.Code
Write-Host $notValobjectID.Message
Write-Host $notValobjectID.Details
Write-Host "##[debug][Template spec]::Getting objectID"
$objectID = (Get-AzTemplateSpec -ResourceGroupName $ResourceGroupNames[0] -Name webAppSpec -Version "1.0.0.0").Versions.objectID
Write-Host "##[debug][Template spec]::Deploying"

$errorMessage=New-AzDeployment `
    -TemplateSpecobjectID $objectID -TemplateParameterFile $TemplateParameterFile `
    -Name $deploymentName -Location $Location `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript `
    -RgList $ResourceGroupNames -KvObjectID $objectID `
    -ErrorVariable notValobjectID -ErrorAction SilentlyContinue
if ($notValobjectID) {
    Write-Host "##[error][Template spec]::Deploying failed"
    Write-Host $errorMessage
    Write-Host $notValobjectID
    Write-Host $notValobjectID.Code
    Write-Host $notValobjectID.Message
    Write-Host $notValobjectID.Details
    throw "Template is not valobjectID according to the valobjectIDation procedure`nTry to Use Get-AzLog -CorrelationobjectID <correlationobjectID> for more info"
}
Write-Host "##[endgroup]"