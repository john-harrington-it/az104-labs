// Lab 04 - Storage account, blob container, lifecycle management, Azure Files (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
//
// As written, this creates a secure StorageV2 account with one private container.
// Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for the storage account.')
param location string = resourceGroup().location

@description('Globally unique storage account name: 3-24 lowercase letters and numbers.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'stlab04${uniqueString(resourceGroup().id)}'

@description('Optional: object ID that gets Storage Blob Data Contributor so you can use --auth-mode login. deploy.ps1 passes your own ID.')
param dataContributorPrincipalId string = ''

var blobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS' // TODO: Make redundancy a parameter (LRS/ZRS/GRS) with @allowed. Which one blocks the Archive tier?
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    // TODO: Add networkAcls driven by a param allowedIpAddresses (string[]):
    //       defaultAction 'Deny' when the list has IPs, 'Allow' when it is empty; bypass 'AzureServices'.
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    // TODO: Turn on blob versioning, blob soft delete (7 days), and container soft delete (7 days).
  }
}

resource docsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: 'private-docs'
  properties: {
    publicAccess: 'None'
  }
}

// TODO: Add a second private container named 'logs'.

// TODO: Add a lifecycle policy (Microsoft.Storage/storageAccounts/managementPolicies, name 'default')
//       for block blobs with prefix 'logs/': Cool after 30 days, Archive after 90, delete after 365.

// TODO: Add Azure Files: fileServices 'default' with share soft delete (7 days), then a share named
//       'departments' with a 5 GiB quota and the TransactionOptimized tier.

resource blobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(dataContributorPrincipalId)) {
  name: guid(storage.id, dataContributorPrincipalId, blobDataContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: blobDataContributorRoleId
    principalId: dataContributorPrincipalId
    principalType: 'User'
    description: 'AZ-104 lab 04: lets the lab user read/write blobs with Entra ID (--auth-mode login).'
  }
}

output storageAccountName string = storage.name
output blobEndpoint string = storage.properties.primaryEndpoints.blob
output containerName string = docsContainer.name
