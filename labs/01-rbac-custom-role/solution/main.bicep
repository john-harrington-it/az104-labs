// Lab 01 - Custom RBAC role + role assignments (reference solution)
// Scope: subscription. Custom role definitions live at subscription (or management group)
// scope, so this file creates the lab resource group, the role, and then assigns roles
// at the resource group scope through a module.
targetScope = 'subscription'

@description('Region for the lab resource group.')
param location string = deployment().location

@description('Lab resource group. The custom role is only assignable here.')
param resourceGroupName string = 'rg-az104-lab01-rbac'

@description('Object ID of the Entra ID security group (or user) that receives the roles.')
param principalId string

@description('Type of principal in principalId. Group is the best practice: assign roles to groups, not people.')
@allowed([
  'Group'
  'User'
  'ServicePrincipal'
])
param principalType string = 'Group'

@description('Display name of the custom role.')
param roleName string = 'AZ-104 Lab VM Operator'

@description('Tags for the resource group.')
param tags object = {
  project: 'az104-labs'
  lab: '01'
  environment: 'study'
  costCenter: 'az104-study'
}

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Custom role: operate VMs (start, restart, deallocate) without being able to create,
// resize, or delete them. Think of it as the Azure version of delegating a narrow set of
// rights on an OU instead of handing out Domain Admins.
resource vmOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  // Role definition names must be GUIDs. guid() makes it deterministic so redeploys update it.
  name: guid(subscription().id, roleName)
  properties: {
    roleName: roleName
    description: 'Can view, start, restart, and deallocate virtual machines in the lab resource group. Cannot create, resize, or delete them.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
          'Microsoft.Compute/virtualMachines/start/action'
          'Microsoft.Compute/virtualMachines/restart/action'
          'Microsoft.Compute/virtualMachines/deallocate/action'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Insights/metrics/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      rg.id
    ]
  }
}

module assignments 'modules/assignments.bicep' = {
  name: 'lab01-role-assignments'
  scope: rg
  params: {
    principalId: principalId
    principalType: principalType
    customRoleDefinitionId: vmOperatorRole.id
  }
}

output resourceGroupId string = rg.id
output customRoleId string = vmOperatorRole.id
output assignmentIds array = assignments.outputs.assignmentIds
