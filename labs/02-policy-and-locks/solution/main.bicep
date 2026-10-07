// Lab 02 - Azure Policy (allowed locations, required/inherited tags) + resource lock (reference solution)
// Scope: resource group. Policy assignments and locks are "extension" resources: deployed
// without a scope, they apply to the resource group this file is deployed into.
targetScope = 'resourceGroup'

@description('Region for the policy assignment managed identity (needed by the Modify effect).')
param location string = resourceGroup().location

@description('Regions where resources in this resource group may be created.')
param allowedLocations string[] = [
  location
]

@description('Tag every resource must carry. The deploy script puts this tag on the resource group.')
param requiredTagName string = 'costCenter'

@description('Lock level for the resource group. CanNotDelete still allows changes; ReadOnly blocks changes too.')
@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param lockLevel string = 'CanNotDelete'

// Built-in policy definitions have the same IDs in every tenant. 'existing' references them
// (at tenant scope) without deploying anything, so we can use their .id below.
resource allowedLocationsDefinition 'Microsoft.Authorization/policyDefinitions@2025-03-01' existing = {
  scope: tenant()
  name: 'e56962a6-4747-49cd-b67b-bf8b01975c4c' // Allowed locations
}

resource requireTagDefinition 'Microsoft.Authorization/policyDefinitions@2025-03-01' existing = {
  scope: tenant()
  name: '871b6d14-10aa-478d-b590-94f262ecfa99' // Require a tag on resources
}

resource inheritTagDefinition 'Microsoft.Authorization/policyDefinitions@2025-03-01' existing = {
  scope: tenant()
  name: 'ea3f2387-9b95-492a-a190-fcdc54f7b070' // Inherit a tag from the resource group if missing
}

// Contributor. The "Inherit a tag" definition lists this role in its roleDefinitionIds.
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

// Deny: block resources outside the allowed regions.
resource allowedLocationsAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'lab02-allowed-locations'
  properties: {
    displayName: 'Lab 02 - Allowed locations'
    description: 'Only allow resources in the approved regions.'
    policyDefinitionId: allowedLocationsDefinition.id
    enforcementMode: 'Default'
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
    nonComplianceMessages: [
      {
        message: 'This region is not allowed in the AZ-104 lab resource group. Allowed: ${join(allowedLocations, ', ')}.'
      }
    ]
  }
}

// Modify: copy the tag from the resource group onto any resource that is missing it.
// Modify (and DeployIfNotExists) need a managed identity with rights to make the change.
resource inheritTagAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'lab02-inherit-${requiredTagName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Lab 02 - Inherit ${requiredTagName} from the resource group'
    policyDefinitionId: inheritTagDefinition.id
    enforcementMode: 'Default'
    parameters: {
      tagName: {
        value: requiredTagName
      }
    }
  }
}

resource inheritTagRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, inheritTagAssignment.id, contributorRoleId)
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: inheritTagAssignment.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'Lets the lab 02 tag-inheritance policy add missing tags (Modify effect and remediation tasks).'
  }
}

// Deny: block any resource that still has no tag. Policy evaluates Modify before Deny,
// so a resource created without the tag gets it from the resource group and passes.
resource requireTagAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'lab02-require-${requiredTagName}'
  properties: {
    displayName: 'Lab 02 - Require ${requiredTagName} tag on resources'
    policyDefinitionId: requireTagDefinition.id
    enforcementMode: 'Default'
    parameters: {
      tagName: {
        value: requiredTagName
      }
    }
    nonComplianceMessages: [
      {
        message: 'Every resource in the lab resource group needs a ${requiredTagName} tag.'
      }
    ]
  }
}

// Lock the whole resource group. Locks override RBAC: even an Owner cannot delete
// the group until the lock is removed (cleanup.ps1 removes it first).
resource rgLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'lab02-${toLower(lockLevel)}'
  properties: {
    level: lockLevel
    notes: 'AZ-104 lab 02. Remove this lock (cleanup.ps1 does it) before deleting the resource group.'
  }
}

output assignmentNames array = [
  allowedLocationsAssignment.name
  inheritTagAssignment.name
  requireTagAssignment.name
]
output lockId string = rgLock.id
