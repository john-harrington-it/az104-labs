// Lab 03 - Tags at resource group and resource level (reference solution)
// Scope: resource group. Management groups are done with Azure CLI in this lab (see README),
// because deploying them from Bicep needs tenant-level deployment rights.
targetScope = 'resourceGroup'

@description('Region for the lab resources.')
param location string = resourceGroup().location

@description('Tags to MERGE onto the resource group. Existing tags (from deploy.ps1) are kept.')
param resourceGroupTags object = {
  owner: 'john-harrington'
  workload: 'az104-governance'
}

@description('Extra tags for the web tier resources. Merged on top of the resource group tags.')
param webTierTags object = {
  tier: 'web'
}

// The Microsoft.Resources/tags resource named 'default' REPLACES the whole tag set on its scope.
// union() keeps whatever is already on the group and adds/overwrites only our keys.
resource rgTags 'Microsoft.Resources/tags@2025-04-01' = {
  name: 'default'
  properties: {
    tags: union(resourceGroup().tags ?? {}, resourceGroupTags)
  }
}

// Tags do NOT inherit automatically. These free resources copy the resource group tags
// explicitly and add their own (lab 02 showed the Azure Policy way to enforce inheritance).
resource webAsg 'Microsoft.Network/applicationSecurityGroups@2025-07-01' = {
  name: 'asg-lab03-web'
  location: location
  tags: union(resourceGroup().tags ?? {}, resourceGroupTags, webTierTags)
}

resource webNsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-lab03-web'
  location: location
  tags: union(resourceGroup().tags ?? {}, resourceGroupTags, webTierTags)
  properties: {
    securityRules: []
  }
}

output effectiveResourceGroupTags object = rgTags.properties.tags
output nsgTags object = webNsg.tags
