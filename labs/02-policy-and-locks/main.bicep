// Lab 02 - Azure Policy (allowed locations, required/inherited tags) + resource lock (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
//
// As written, this assigns the built-in "Allowed locations" policy to the resource group.
// Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Regions where resources in this resource group may be created.')
param allowedLocations string[] = [
  resourceGroup().location
]

// Built-in policy definitions have the same IDs in every tenant. 'existing' references them
// (at tenant scope) without deploying anything, so we can use their .id below.
// Find more with: az policy definition list --query "[?policyType=='BuiltIn' && contains(displayName, 'tag')].{name:name, displayName:displayName}" -o table
resource allowedLocationsDefinition 'Microsoft.Authorization/policyDefinitions@2025-03-01' existing = {
  scope: tenant()
  name: 'e56962a6-4747-49cd-b67b-bf8b01975c4c' // Allowed locations
}

// TODO: Add existing references for:
//       'Require a tag on resources'                       (871b6d14-10aa-478d-b590-94f262ecfa99)
//       'Inherit a tag from the resource group if missing' (ea3f2387-9b95-492a-a190-fcdc54f7b070)

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
  }
}

// TODO: Add a param requiredTagName (default 'costCenter') and a policy assignment that DENIES
//       resources without that tag (definition parameter name: tagName).

// TODO: Add a policy assignment for "Inherit a tag from the resource group if missing".
//       It uses the Modify effect, so it needs: a location, identity: { type: 'SystemAssigned' },
//       and a role assignment (Contributor, b24988ac-6180-42a0-ab88-20f7382dd24c) for
//       inheritTagAssignment.identity.principalId with principalType 'ServicePrincipal'.

// TODO: Add a Microsoft.Authorization/locks@2020-05-01 resource with level 'CanNotDelete'.
//       With no scope property, the lock applies to the whole resource group.

output assignmentNames array = [
  allowedLocationsAssignment.name
]
