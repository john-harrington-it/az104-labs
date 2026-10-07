// Lab 11 - Recovery Services vault + enhanced VM backup policy + protected VM (reference solution)
// Scope: resource group. Costs: a B1s VM plus Azure Backup's per-instance fee and snapshot storage,
// billed while protected. Run cleanup.ps1 the same day.
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

@description('Daily backup time (UTC, HH:mm). 05:00 UTC is 11 PM or midnight US Central, depending on DST.')
param backupTimeUtc string = '05:00'

@description('Days to keep daily recovery points (minimum 7).')
@minValue(7)
@maxValue(30)
param dailyRetentionDays int = 7

@description('Soft delete keeps deleted backup data for 14+ days. Disabled here ONLY so the lab cleans up the same day. Keep it enabled in production.')
@allowed([
  'Enabled'
  'Disabled'
])
param softDeleteState string = 'Disabled'

var scheduleTime = '2026-01-01T${backupTimeUtc}:00Z' // only the time part is used

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
      standardTierStorageRedundancy: 'LocallyRedundant' // cheapest; GRS is the default for new vaults
      crossRegionRestore: 'Disabled'
    }
    securitySettings: {
      softDeleteSettings: {
        softDeleteState: softDeleteState
        softDeleteRetentionPeriodInDays: 14
      }
    }
  }
}

// Enhanced policy (V2): required for Trusted Launch VMs and supports multiple backups per day.
resource dailyPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2025-02-01' = {
  parent: vault
  name: 'policy-daily-${dailyRetentionDays}d'
  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType: 'V2'
    instantRpRetentionRangeInDays: 2 // snapshots kept locally for fast restores
    timeZone: 'UTC'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule: {
        scheduleRunTimes: [
          scheduleTime
        ]
      }
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          scheduleTime
        ]
        retentionDuration: {
          count: dailyRetentionDays
          durationType: 'Days'
        }
      }
    }
  }
}

module labVm '../../../modules/small-linux-vm.bicep' = {
  name: 'lab11-vm'
  params: {
    location: location
    vmName: vmName
    adminPublicKey: adminPublicKey
    addressPrefix: '10.110.0.0/16'
  }
}

// Protecting a VM = a protected item under the Azure fabric with these fixed container/item names.
var containerName = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
var protectedItemName = 'vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'

resource protectedVm 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-02-01' = {
  name: '${vault.name}/Azure/${containerName}/${protectedItemName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: dailyPolicy.id
    sourceResourceId: labVm.outputs.vmId
  }
}

output vaultName string = vault.name
output policyName string = dailyPolicy.name
output containerName string = containerName
output protectedItemName string = protectedItemName
output protectedItemId string = protectedVm.id
