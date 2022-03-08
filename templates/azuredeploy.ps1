param($Location, $prefix, $slackURL, $userObjectID)
$ws=Get-AzContext
$ws.Name
$name = $ws.Name.Split()[-1]
$name.Length
$app=$name+"ESRA"
$app
Write-Host "##[section]END"
exit
Write-Host "##[section]Preparations"
Write-Host "##[debug]Loading main template files"

$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "scripts\alertScript.csx" -Raw
. "scripts\generatePass.ps1"

Write-Host "##[debug]Setting variables"
if (!$prefix) {$prefix = 'armeschool'}

$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="WebAppDeploy"+"${today}"

$DbPassFromKV = Get-AzKeyVaultSecret -VaultName 'kv-upser-eastus' -Name 'db-upser-eastusPass'
if ( !$DbPassFromKV ) {
    $DatabasePassword = ConvertTo-SecureString (Get-RandomPassword 8)  -AsPlainText -Force }
else {
    $DatabasePassword = $DbPassFromKV}
$slackURL = ConvertTo-SecureString $slackURL  -AsPlainText -Force

Write-Host "##[debug]Getting resource group"
$ResourceGroupNames = @()
$ResourceGroupNames += "rg-"+$prefix+"-common-base-"+$Location
$ResourceGroupNames +="rg-"+$prefix+"-common-metrics-"+$Location
$ResourceGroupNames += "rg-"+$prefix+"-APP-"+$Location

Write-Host "##[debug]Resource groups to deploy::$ResourceGroupNames"
Foreach ($rg in $ResourceGroupNames){
    
    Get-AzResourceGroup -Name $rg -ErrorVariable notPresent -ErrorAction silentlycontinue
    if ($notPresent) {
        New-AzResourceGroup -Name $rg -Location $Location
    }
}

Write-Host "##[endgroup]"
Write-Host "##[section]Deploying template"
Write-Host "##[debug][Template spec]::Create"
New-AzTemplateSpec `
    -Name webAppSpec `
    -Version "1.0.0.0" `
    -ResourceGroupName $ResourceGroupNames[0] `
    -Location $Location `
    -TemplateFile "templates\azuredeploy.json" `
    -Force -Confirm:$false `
    -ErrorVariable notValid -ErrorAction SilentlyContinue
Write-Host $notValid
Write-Host $notValid.Code
Write-Host $notValid.Message
Write-Host $notValid.Details
Write-Host "##[debug][Template spec]::Getting ID"
$id = (Get-AzTemplateSpec -ResourceGroupName $ResourceGroupNames[0] -Name webAppSpec -Version "1.0.0.0").Versions.Id
Write-Host "##[debug][Template spec]::Deploying"

$errorMessage=New-AzDeployment `
    -TemplateSpecId $id -TemplateParameterFile $TemplateParameterFile `
    -Name $deploymentName -Location $Location `
    -prefix $prefix  -databasePassword $databasePassword `
    -slackURL $slackURL -alertScript $alertScript `
    -RgList $ResourceGroupNames -userObjectID $userObjectID `
    -ErrorVariable notValid -ErrorAction SilentlyContinue
if ($notValid) {
    Write-Host "##[error][Template spec]::Deploying failed"
    Write-Host $errorMessage
    Write-Host $notValid
    Write-Host $notValid.Code
    Write-Host $notValid.Message
    Write-Host $notValid.Details
    throw "Template is not valid according to the validation procedure`nTry to Use Get-AzLog -CorrelationId <correlationId> for more info"
}
Write-Host "##[endgroup]"