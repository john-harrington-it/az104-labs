// Lab 01 - Custom RBAC role + role assignments (STARTER)
// Scope: subscription. Deploy with ./deploy.ps1 (runs what-if first).
//
// As written, this creates the resource group and a custom role that can only READ VMs,
// then assigns built-in Reader to your group. Finish the TODOs here and in
// modules/assignments.bicep, then compare with the solution folder.
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

resource vmOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, roleName)
  properties: {
    roleName: roleName
    description: 'Can view, start, restart, and deallocate virtual machines in the lab resource group.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Compute/virtualMachines/read'
          // TODO: Add the actions needed to start, restart, and deallocate a VM.
          //       Find them with: az provider operation show --namespace Microsoft.Compute --query "resourceTypes[?name=='virtualMachines'].operations[].name" -o tsv
          // TODO: Add read access to network interfaces and to metrics so the role can see the VM's NIC and charts.
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    // TODO: Why is this limited to the resource group instead of the whole subscription?
    //       Write your answer in the "My notes" section of the README.
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
    // TODO: After you add a customRoleDefinitionId parameter to the module, pass vmOperatorRole.id here.
  }
}

output resourceGroupId string = rg.id
output customRoleId string = vmOperatorRole.id
