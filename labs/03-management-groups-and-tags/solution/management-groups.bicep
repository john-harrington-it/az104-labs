// Lab 03 - Management group hierarchy as code (reference only; optional to deploy)
//
// This is the Bicep version of the CLI steps in the README. It is here so you can practice
// READING a tenant-scope template (an exam skill). Deploying it needs rights at the tenant
// root (for example, a Global Administrator who has elevated access), so the lab itself
// uses: az account management-group create
//
// Optional deploy: az deployment tenant what-if --location southcentralus --template-file management-groups.bicep
targetScope = 'tenant'

@description('ID (name) of the top-level lab management group.')
param rootGroupName string = 'mg-az104-lab'

@description('ID (name) of the child management group for sandbox subscriptions.')
param sandboxGroupName string = 'mg-az104-sandbox'

resource labRoot 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: rootGroupName
  properties: {
    displayName: 'AZ-104 Lab'
  }
}

resource sandbox 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: sandboxGroupName
  properties: {
    displayName: 'AZ-104 Lab - Sandbox'
    details: {
      parent: {
        id: labRoot.id
      }
    }
  }
}

output rootGroupId string = labRoot.id
output sandboxGroupId string = sandbox.id
