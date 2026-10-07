// Lab 08 - App Service plan + Linux web app, with optional scale-up for deployment slots (reference solution)
// Scope: resource group. Default tier F1 (Free) costs nothing. S1 is needed for slots and autoscale;
// it bills by the hour, so scale back down or run cleanup.ps1 when you finish.
targetScope = 'resourceGroup'

@description('Region for the plan and app.')
param location string = resourceGroup().location

@description('Globally unique app name (becomes <name>.azurewebsites.net).')
param webAppName string = 'app-lab08-${uniqueString(resourceGroup().id)}'

@description('Plan SKU. F1 = Free (no slots, no custom TLS, no Always On). B1 = Basic. S1 = Standard (slots, autoscale).')
@allowed([
  'F1'
  'B1'
  'S1'
])
param skuName string = 'F1'

@description('Number of instances (F1 is always 1).')
@minValue(1)
@maxValue(3)
param instanceCount int = 1

@description('Runtime stack for Linux App Service.')
param linuxFxVersion string = 'NODE|22-lts'

var supportsSlots = startsWith(skuName, 'S')

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: 'asp-lab08'
  location: location
  kind: 'linux'
  sku: {
    name: skuName
    capacity: skuName == 'F1' ? 1 : instanceCount
  }
  properties: {
    reserved: true // required for Linux plans
  }
}

resource webApp 'Microsoft.Web/sites@2025-03-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned' // lets the app reach Key Vault/Storage with Entra ID instead of secrets
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appCommandLine: 'node server.js'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: skuName != 'F1' // Always On is not available on Free
      healthCheckPath: '/'
      appSettings: [
        {
          name: 'LAB_SLOT_NAME'
          value: 'production'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
      ]
    }
  }
}

// Turn off FTP basic-auth publishing credentials (security baseline). Zip deploy still works.
resource ftpBasicAuth 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2025-03-01' = {
  parent: webApp
  name: 'ftp'
  properties: {
    allow: false
  }
}

// Deployment slot (Standard tier and above): deploy to staging, test, then swap.
resource stagingSlot 'Microsoft.Web/sites/slots@2025-03-01' = if (supportsSlots) {
  parent: webApp
  name: 'staging'
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appCommandLine: 'node server.js'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'LAB_SLOT_NAME'
          value: 'staging'
        }
      ]
    }
  }
}

output webAppName string = webApp.name
output url string = 'https://${webApp.properties.defaultHostName}'
output stagingUrl string = supportsSlots ? 'https://${stagingSlot!.properties.defaultHostName}' : 'n/a (needs S1)'
output principalId string = webApp.identity.principalId
