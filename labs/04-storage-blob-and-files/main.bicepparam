using 'main.bicep'

// deploy.ps1 sets AZ104_PRINCIPAL_ID to your own Entra ID object ID.
param dataContributorPrincipalId = readEnvironmentVariable('AZ104_PRINCIPAL_ID', '')
