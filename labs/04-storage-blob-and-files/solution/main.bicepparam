using 'main.bicep'

// deploy.ps1 sets AZ104_PRINCIPAL_ID to your own Entra ID object ID.
param dataContributorPrincipalId = readEnvironmentVariable('AZ104_PRINCIPAL_ID', '')

param skuName = 'Standard_LRS'
param fileShareQuotaGiB = 5

// Lock the storage firewall to your public IP (find it with: curl https://ifconfig.me). Empty = all networks.
param allowedIpAddresses = []
