// Shared module: a small Ubuntu VM in its own VNet, no public IP.
// Used by labs that need "a VM to point something at" (for example lab 11 backup).
// Lab 07 builds the same thing by hand so you learn every piece; this is the reusable version.
targetScope = 'resourceGroup'

@description('Region for the VM and its network.')
param location string = resourceGroup().location

@description('VM name (also the computer name).')
@maxLength(15)
param vmName string

@description('VM size.')
param vmSize string = 'Standard_B1s'

@description('Local admin user name.')
param adminUsername string = 'labadmin'

@description('SSH public key.')
@secure()
param adminPublicKey string

@description('VNet address space. The VM subnet is the first /24.')
param addressPrefix string = '10.100.0.0/16'

@description('Allow default outbound internet access from the subnet. Backup and extensions need outbound connectivity; production would use NAT Gateway.')
param defaultOutboundAccess bool = true

@description('Tags applied to every resource in the module.')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-${vmName}'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: 'vnet-${vmName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 0)
          networkSecurityGroup: {
            id: nsg.id
          }
          defaultOutboundAccess: defaultOutboundAccess
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2025-07-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
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

resource vm 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: vmName
  location: location
  tags: tags
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
              keyData: adminPublicKey
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

output vmId string = vm.id
output vmName string = vm.name
