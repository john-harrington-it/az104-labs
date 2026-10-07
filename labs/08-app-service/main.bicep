// Lab 08 - App Service plan + Linux web app (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first). F1 (Free) costs nothing.
//
// As written, this creates a Free Linux plan and a Node.js web app. Finish the TODOs, then compare
// with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for the plan and app.')
param location string = resourceGroup().location

@description('Globally unique app name (becomes <name>.azurewebsites.net).')
param webAppName string = 'app-lab08-${uniqueString(resourceGroup().id)}'

@description('Runtime stack for Linux App Service. List options: az webapp list-runtimes --os linux')
param linuxFxVersion string = 'NODE|22-lts'

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: 'asp-lab08'
  location: location
  kind: 'linux'
  sku: {
    name: 'F1' // TODO: Make the SKU a parameter allowing F1, B1, S1. What does each tier add?
  }
  properties: {
    reserved: true // required for Linux plans
  }
}

resource webApp 'Microsoft.Web/sites@2025-03-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      appCommandLine: 'node server.js'
      // TODO: Harden the app: httpsOnly (on the site properties), minTlsVersion '1.2', ftpsState 'Disabled'.
      // TODO: Add an app setting LAB_SLOT_NAME = 'production' (the sample app prints it).
    }
  }
  // TODO: Give the app a system-assigned managed identity.
}

// TODO: Disable FTP basic-auth publishing (Microsoft.Web/sites/basicPublishingCredentialsPolicies, name 'ftp', allow: false).

// TODO (costs money, delete within the hour): when the SKU starts with 'S', add a deployment slot
//       named 'staging' (Microsoft.Web/sites/slots) with LAB_SLOT_NAME = 'staging'. Use a condition: if (...)

output webAppName string = webApp.name
output url string = 'https://${webApp.properties.defaultHostName}'
