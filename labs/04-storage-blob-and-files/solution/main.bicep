// Lab 04 - Storage account: private blob container, versioning/soft delete, lifecycle
// management, Azure Files share, and optional firewall (reference solution)
// Scope: resource group.
targetScope = 'resourceGroup'

@description('Region for the storage account.')
param location string = resourceGroup().location

@description('Globally unique storage account name: 3-24 lowercase letters and numbers.')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'stlab04${uniqueString(resourceGroup().id)}'

@description('Redundancy. LRS is the cheapest. Note: the Archive tier is not available on ZRS/GZRS accounts.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
])
param skuName string = 'Standard_LRS'

@description('Public IPv4 addresses allowed through the storage firewall. Empty = allow all networks (lab default).')
param allowedIpAddresses string[] = []

@description('Quota for the Azure Files share in GiB.')
@minValue(1)
@maxValue(100)
param fileShareQuotaGiB int = 5

@description('Optional: object ID that gets Storage Blob Data Contributor so you can use --auth-mode login. deploy.ps1 passes your own ID.')
param dataContributorPrincipalId string = ''

// Storage Blob Data Contributor (data plane). Management-plane roles like Owner do NOT
// grant blob data access on their own when you use Entra ID auth.
var blobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false // no anonymous access, ever
    allowSharedKeyAccess: true // needed for the account-key and service SAS steps; production often turns this off
    defaultToOAuthAuthentication: true // portal uses Entra ID instead of keys by default
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: empty(allowedIpAddresses) ? 'Allow' : 'Deny'
      ipRules: [
        for ip in allowedIpAddresses: {
          value: ip
          action: 'Allow'
        }
      ]
    }
    encryption: {
      keySource: 'Microsoft.Storage' // Microsoft-managed keys (customer-managed keys would use Key Vault)
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource docsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: 'private-docs'
  properties: {
    publicAccess: 'None'
  }
}

resource logsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: 'logs'
  properties: {
    publicAccess: 'None'
  }
}

// Lifecycle management: Hot -> Cool (30 days) -> Archive (90 days) -> delete (365 days)
// for block blobs under logs/. Old versions and snapshots are cleaned up after 90 days.
resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2025-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'tier-and-expire-logs'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'logs/'
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: 90
                }
                delete: {
                  daysAfterModificationGreaterThan: 365
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 90
                }
              }
              version: {
                delete: {
                  daysAfterCreationGreaterThan: 90
                }
              }
            }
          }
        }
      ]
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2025-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Azure Files share: the cloud version of a departmental file server share.
resource departmentsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-06-01' = {
  parent: fileService
  name: 'departments'
  properties: {
    shareQuota: fileShareQuotaGiB
    accessTier: 'TransactionOptimized'
    enabledProtocols: 'SMB'
  }
}

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
output fileEndpoint string = storage.properties.primaryEndpoints.file
output containerNames array = [
  docsContainer.name
  logsContainer.name
]
output fileShareName string = departmentsShare.name
