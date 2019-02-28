# Azure Cloud Gaming

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnyanhp%2FAzureCloudGaming%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fnyanhp%2FAzureCloudGaming%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

Cloud gaming on Azure powered by NVidia Tesla and PowerShell!

## Description

This repository contains all you need to deploy a powerful VM on Azure to get your game on :) Using an ARM template and DSC we will deploy:

- Standard NV6 VM (NVidia Tesla M60, 56 GiB RAM, 128 GiB SSD OS Disk)
- Installed software
  - Steam
  - Origin
  - UPlay
  - Parsec for game streaming ([Parsec](https://parsecgaming.com/))
- Configuration
  - Auto-logon of user account
  - Virtual Audio Cable
  - 500 GiB SSD for game data

By deploying this template you invariably accept all license agreements and whatnot by:

- Steam
- Origin
- Ubisoft
- Parsec
- NVidia
- Eugene Muzychenko (Virtual Audio Cable)

## After deployment

After the deployment has finished, everything should be set up. Since there is no way currently to pass initial credentials to Parsec, you need to login to the app manually. In order to do this, either use the command line returned after the deployment, or simply use RDP to connect.
