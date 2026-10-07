// Lab 11 - Recovery Services vault + VM backup policy (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
// Costs: a B1s VM, plus Azure Backup fees once the VM is protected. Run cleanup.ps1 the same day.
//
// As written, this creates the vault and a small VM (from the shared module). Finish the TODOs to
// add a backup policy and protect the VM, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for the vault and VM (a vault can only protect VMs in its own region).')
param location string = resourceGroup().location

@description('Recovery Services vault name.')
param vaultName string = 'rsv-lab11-${uniqueString(resourceGroup().id)}'

@description('Name of the VM to protect.')
@maxLength(15)
param vmName string = 'vm-lab11'

@description('SSH public key for the lab VM. deploy.ps1 fills this in.')
@secure()
param adminPublicKey string

resource vault 'Microsoft.RecoveryServices/vaults@2025-02-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    redundancySettings: {
      standardTierStorageRedundancy: 'LocallyRedundant'
      crossRegionRestore: 'Disabled'
    }
    securitySettings: {
      softDeleteSettings: {
        // Disabled ONLY so the lab cleans up the same day. Keep soft delete on in production.
        softDeleteState: 'Disabled'
        softDeleteRetentionPeriodInDays: 14
      }
    }
  }
}

module labVm '../../modules/small-linux-vm.bicep' = {
  name: 'lab11-vm'
  params: {
    location: location
    vmName: vmName
    adminPublicKey: adminPublicKey
    addressPrefix: '10.110.0.0/16'
  }
}

// TODO: Add an ENHANCED backup policy (Microsoft.RecoveryServices/vaults/backupPolicies@2025-02-01, parent: vault):
//       backupManagementType 'AzureIaasVM', policyType 'V2', schedulePolicyType 'SimpleSchedulePolicyV2',
//       daily at 05:00 UTC, keep daily points 7 days. Why does this VM need the enhanced (V2) policy?

// TODO: Protect the VM: Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-02-01
//       name: '${vault.name}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}/vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
//       properties: protectedItemType 'Microsoft.Compute/virtualMachines', policyId, sourceResourceId: labVm.outputs.vmId

output vaultName string = vault.name
output vmId string = labVm.outputs.vmId
