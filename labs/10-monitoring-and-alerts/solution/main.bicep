// Lab 10 - Azure Monitor: Log Analytics, diagnostic settings, metric + activity log alerts,
// and an action group (reference solution)
// Scope: resource group. The workspace has a small daily ingestion cap so it cannot run up a bill.
targetScope = 'resourceGroup'

@description('Region for the workspace and storage account.')
param location string = resourceGroup().location

@description('Email that receives alert notifications. deploy.ps1 sets AZ104_ALERT_EMAIL.')
param alertEmail string

@description('Log Analytics daily ingestion cap in GB. 0.1 GB/day keeps this lab at pennies.')
param dailyQuotaGb string = '0.1'

@description('Transactions in 5 minutes that trigger the metric alert. Low on purpose so you can trigger it.')
param transactionThreshold int = 50

@description('Optional: object ID that gets Storage Blob Data Contributor so you can generate traffic with --auth-mode login.')
param dataContributorPrincipalId string = ''

var blobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-lab10-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018' // pay-as-you-go; the first 5 GB/month per billing account are free
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json(dailyQuotaGb)
    }
  }
}

// Something to monitor: a storage account (cheap, and it has both metrics and resource logs).
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

// Diagnostic settings are an extension resource: 'scope' is the thing being monitored.
// Storage resource logs live on the service (blob/file/queue/table), not on the account.
// 2021-05-01-preview is the version Microsoft's own docs and samples use for diagnostic settings.
#disable-next-line use-recent-api-versions
resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-log-analytics'
  scope: blobService
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-lab10-email'
  location: 'global'
  properties: {
    groupShortName: 'az104lab' // max 12 characters; shows in SMS/email
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

// Metric alert: fires when blob transactions spike. Metric alerts bill per monitored time series
// (about $0.10/month each), prorated, so a few hours costs a fraction of a cent.
resource transactionsAlert 'Microsoft.Insights/metricAlerts@2026-01-01' = {
  name: 'alert-lab10-storage-transactions'
  location: 'global'
  properties: {
    description: 'More than ${transactionThreshold} storage transactions in 5 minutes.'
    severity: 3
    enabled: true
    scopes: [
      storage.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighTransactions'
          criterionType: 'StaticThresholdCriterion'
          metricNamespace: 'Microsoft.Storage/storageAccounts'
          metricName: 'Transactions'
          operator: 'GreaterThan'
          threshold: transactionThreshold
          timeAggregation: 'Total'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Activity log alert (free): someone regenerated a storage account key in this resource group.
resource keyRegenAlert 'Microsoft.Insights/activityLogAlerts@2026-01-01' = {
  name: 'alert-lab10-storage-key-regenerated'
  location: 'global'
  properties: {
    description: 'A storage account access key was regenerated in the lab resource group.'
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Storage/storageAccounts/regenerateKey/action'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

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
output actionGroupId string = actionGroup.id
