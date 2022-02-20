param($token,$repoLink,$dir,$branch)
$templateFiles=Get-ChildItem -Path $dir -Name
Write-Host "##[debug]List of templates to proceed: $templateFiles"

Write-Host "##[debug]Preparing REST method"
$owner,$repo=$repoLink.Replace('https://github.com/','').Split('/')
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "token $token")
$headers.Add("Accept", "application/vnd.github.v3+json")

Write-Host "##[debug]Obtain template links"
$templateUrlList = @()

Foreach ($file in $templateFiles){
    $fullpath="https://api.github.com/repos/$owner/$repo/contents/$dir?ref=$branch"
    $response = (Invoke-RestMethod $fullpath -Method 'GET' -Headers $headers -Body $body) 
    $templateUrlList.Add($response.download_url)
}

$l=$templateUrlList.Length
Write-Host "##[debug]Returning $l template link(s)"
Write-Host "##vso[task.setvariable variable=templateUrlList;isOutput=true]$templateUrlList"