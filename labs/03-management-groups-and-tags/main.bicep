// Lab 03 - Tags at resource group and resource level (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
// Management groups are done with Azure CLI in this lab (see README).
//
// As written, this creates a tagged NSG. Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for the lab resources.')
param location string = resourceGroup().location

@description('Extra tags for the web tier resources.')
param webTierTags object = {
  tier: 'web'
}

// TODO: Add a param resourceGroupTags (object) with owner and workload tags, and a
//       Microsoft.Resources/tags@2025-04-01 resource named 'default' that MERGES them onto the
//       resource group. Careful: the tags resource REPLACES the whole tag set. Use union() with
//       resourceGroup().tags so the tags from deploy.ps1 survive. Run what-if and read the diff.

resource webNsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-lab03-web'
  location: location
  // TODO: This only sets tier=web. Change it so the NSG also carries every resource group tag.
  tags: webTierTags
  properties: {
    securityRules: []
  }
}

// TODO: Add an application security group (Microsoft.Network/applicationSecurityGroups@2025-07-01)
//       named asg-lab03-web with the same tags as the NSG.

output nsgTags object = webNsg.tags
