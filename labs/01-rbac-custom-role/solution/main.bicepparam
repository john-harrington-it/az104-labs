using 'main.bicep'

// Object ID of the Entra ID group that gets the roles. deploy.ps1 looks up the group
// (default: AZ104-Lab-Operators) and sets AZ104_PRINCIPAL_ID for you.
param principalId = readEnvironmentVariable('AZ104_PRINCIPAL_ID', '00000000-0000-0000-0000-000000000000')

param principalType = 'Group'
param resourceGroupName = 'rg-az104-lab01-rbac'
