param($Location, $prefix, $slackURL, $userObjectID)
Write-Host "##[section]Preparations"
Write-Host "##[debug]Loading main template files"

$TemplateFile="templates\azuredeploy.json"
$TemplateParameterFile="templates\azuredeploy.parameters.json"
$alertScript = Get-Content -Path "scripts\alertScript.csx" -Raw
. "scripts\generatePass.ps1"

Write-Host "##[debug]Setting variables"
Write-Host "##[debug]Setting variables::Get current appID & objectID"

$context=Get-AzContext
$current_appID = $context.Name.Split()[-1]
$app=Get-AzADServicePrincipal -Filter "AppId eq '$accountName'"
$current_objID = $app.Id

Write-Host "##[debug]Setting variables:Default variables"
if (!$prefix) {$prefix = 'armeschool'}
$today=Get-Date -Format "MM-dd-yyyy-HH-mm"
$deploymentName="eSchoolProjectDEPLOY"+"${today}"

Write-Host "##[debug]Setting variables:Lookup for secrets from KV"
$DbPassFromKV = Get-AzKeyVaultSecret -VaultName 'kv-upser-eastus' -Name 'db-upser-eastusPass' -ErrorVariable notPresent -ErrorAction silentlycontinue
if ($notPresent) {
    Write-Host "##[warning]Access denied for KV"
    Write-Host $notPresent.Message
    Write-Host "##[debug]Creating new infrastructure"
}
if ( !$DbPassFromKV ) {
    Write-Host "##[debug]Generating new secrets"
    $DatabasePassword = ConvertTo-SecureString (Get-RandomPassword 8)  -AsPlainText -Force }
else {
    Write-Host "##[debug]Getting secrets from KV"
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
    -appID $current_appID -tenantID $current_appID `
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