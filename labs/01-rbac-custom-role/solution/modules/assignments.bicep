// Role assignments at resource group scope (reference solution).
targetScope = 'resourceGroup'

@description('Object ID of the group or user that receives the roles.')
param principalId string

@description('Group, User, or ServicePrincipal.')
param principalType string

@description('Full resource ID of the custom role definition.')
param customRoleDefinitionId string

// Built-in role IDs are the same in every tenant. Reader = acdd72a7-3385-48ef-bd42-f606fba81ae7
var readerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

// Reader on the resource group: see everything, change nothing.
resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Assignment names must be GUIDs and unique per scope + principal + role.
  name: guid(resourceGroup().id, principalId, readerRoleDefinitionId)
  properties: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: principalId
    principalType: principalType
    description: 'AZ-104 lab 01: read-only access to the lab resource group.'
  }
}

// Custom VM Operator role on the same resource group. Permissions are additive:
// the principal ends up with Reader + the extra VM power actions.
resource customAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, customRoleDefinitionId)
  properties: {
    roleDefinitionId: customRoleDefinitionId
    principalId: principalId
    principalType: principalType
    description: 'AZ-104 lab 01: start, restart, and deallocate VMs in the lab resource group.'
  }
}

output assignmentIds array = [
  readerAssignment.id
  customAssignment.id
]
