// Lab 07 - Linux virtual machine with managed disks, an extension, and auto-shutdown (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
// No public IP: you manage the VM with az vm run-command (no open ports).
//
// As written, this deploys a small Ubuntu VM with an OS disk. Finish the TODOs, then compare
// with solution/main.bicep (which also supports Windows).
targetScope = 'resourceGroup'

@description('Region for the VM.')
param location string = resourceGroup().location

@description('VM name (also used as the computer name).')
@maxLength(15)
param vmName string = 'vm-lab07'

@description('VM size. Standard_B1s is free-tier eligible on many free accounts.')
param vmSize string = 'Standard_B1s'

@description('Local admin user name.')
param adminUsername string = 'labadmin'

@description('SSH public key. deploy.ps1 fills this in from ~/.ssh; never commit it.')
@secure()
param adminPasswordOrKey string

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-${vmName}'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: 'vnet-lab07'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.70.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: '10.70.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          // New VNets are private by default (no internet egress). The extension TODO below needs to
          // download packages, so this lab opts back in. Production answer: NAT Gateway or a firewall.
          defaultOutboundAccess: true
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2025-07-01' = {
  name: 'nic-${vmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// TODO: Add a 4 GiB empty managed data disk (Microsoft.Compute/disks@2025-01-02, sku Standard_LRS,
//       creationData.createOption 'Empty') and attach it to the VM below at LUN 0.

resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        name: 'disk-${vmName}-os'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      // TODO: dataDisks: [ ... ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPasswordOrKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// TODO: Add a CustomScript extension (Microsoft.Compute/virtualMachines/extensions@2025-04-01,
//       publisher Microsoft.Azure.Extensions, type CustomScript, typeHandlerVersion 2.1) that installs nginx.
//       Put commandToExecute in protectedSettings, not settings. Why?

// TODO: Add auto-shutdown: Microsoft.DevTestLab/schedules@2018-09-15 named 'shutdown-computevm-${vmName}',
//       taskType 'ComputeVmShutdownTask', dailyRecurrence.time '1900', timeZoneId 'Central Standard Time',
//       targetResourceId vm.id. This is the single best way to keep VM labs cheap.

output vmName string = vm.name
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
