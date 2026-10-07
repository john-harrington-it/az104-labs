// Lab 10 - Azure Monitor: Log Analytics, diagnostic settings, alerts, action group (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
//
// As written, this creates a capped Log Analytics workspace, a storage account to monitor, and an
// email action group. Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for the workspace and storage account.')
param location string = resourceGroup().location

@description('Email that receives alert notifications. deploy.ps1 sets AZ104_ALERT_EMAIL.')
param alertEmail string

@description('Optional: object ID that gets Storage Blob Data Contributor so you can generate traffic with --auth-mode login.')
param dataContributorPrincipalId string = ''

var blobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-lab10-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.1') // daily ingestion cap: the cost guardrail for this lab
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: 'stlab10${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' existing = {
  parent: storage
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: 'monitored'
  properties: {
    publicAccess: 'None'
  }
}

// TODO: Add a diagnostic setting (Microsoft.Insights/diagnosticSettings@2021-05-01-preview) with
//       scope: blobService that sends StorageRead, StorageWrite, StorageDelete logs and the
//       Transaction metric to the workspace. (Put '#disable-next-line use-recent-api-versions' above it;
//       read the comment in the solution to see why.)

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-lab10-email'
  location: 'global'
  properties: {
    groupShortName: 'az104lab'
    enabled: true
    emailReceivers: [
      {
        name: 'lab-owner'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// TODO: Add a metric alert (Microsoft.Insights/metricAlerts@2026-01-01, location 'global') on the storage
//       account: Transactions, Total, GreaterThan 50, window PT5M, frequency PT1M, action = actionGroup.

// TODO: Add an activity log alert (Microsoft.Insights/activityLogAlerts@2026-01-01, location 'global')
//       scoped to the resource group for operationName 'Microsoft.Storage/storageAccounts/regenerateKey/action'.

resource blobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(dataContributorPrincipalId)) {
  name: guid(storage.id, dataContributorPrincipalId, blobDataContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: blobDataContributorRoleId
    principalId: dataContributorPrincipalId
    principalType: 'User'
    description: 'AZ-104 lab 10: lets the lab user generate blob traffic with --auth-mode login.'
  }
}

output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
output storageAccountName string = storage.name
output containerName string = container.name
