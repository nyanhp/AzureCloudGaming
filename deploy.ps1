New-AzResourceGroup -Name CloudGamingRg -Location 'westeurope'

$parameters = @{
    Name              = 'CloudGaming'
    ResourceGroupName = 'CloudGamingRg'
    TemplateFile      = "$psscriptroot\azuredeploy.json"
    dnsLabelPrefix    = "cloudgaming$((1..13 | ForEach-Object { [char[]](97..122) | Get-Random }) -join '')"
    adminUsername     = Read-Host -Prompt 'Username please'
    adminPassword     = Read-Host -AsSecureString -Prompt 'Enter admin password'
    librarySizeGB     = 1024
}

New-AzResourceGroupDeployment @parameters
Restart-AzVm -Name TheBeast -ResourceGroupName CloudGamingRg -PerformMaintenance
