$rg=""
$storageAccount = New-AzStorageAccount -ResourceGroupName $rg `
                  -Name armtempstorage `
                  -SkuName Standart_LRS `
                  -Location eastus


$context = $storageAccount.Context

$containerName = 'armblobs'

New-AzStorageContainer -Name $containerName -Context $context -Permission blob


Remove-AzStorageAccount -Name armtempstorage -ResourceGroupName $rg