// Lab 07 - Virtual machine with managed disks, an extension, and auto-shutdown (reference solution)
// Scope: resource group. No public IP: you manage the VM with az vm run-command (no open ports).
targetScope = 'resourceGroup'

@description('Region for the VM.')
param location string = resourceGroup().location

@description('VM name (also used as the computer name).')
@maxLength(15)
param vmName string = 'vm-lab07'

@description('Linux (Ubuntu 24.04, SSH key) or Windows (Server 2022, password).')
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

@description('VM size. Standard_B1s is free-tier eligible on many free accounts; for Windows consider Standard_B2ats_v2 (1 GiB RAM on B1s is painful for Windows).')
param vmSize string = 'Standard_B1s'

@description('Local admin user name.')
param adminUsername string = 'labadmin'

@description('SSH public key (Linux) or password (Windows). deploy.ps1 fills this in; never commit it.')
@secure()
param adminPasswordOrKey string

@description('Size of the extra data disk in GiB (Standard HDD, LRS).')
@minValue(4)
@maxValue(64)
param dataDiskSizeGiB int = 4

@description('Turn on daily auto-shutdown (deallocate). Strongly recommended for labs.')
param enableAutoShutdown bool = true

@description('Auto-shutdown time, 24-hour HHmm.')
param autoShutdownTime string = '1900'

@description('Windows time zone ID for the shutdown schedule.')
param autoShutdownTimeZone string = 'Central Standard Time'

@description('Optional email for a 30-minute warning before auto-shutdown.')
param autoShutdownEmail string = ''

@description('Encryption at host (exam topic). Needs a one-time feature registration: az feature register --namespace Microsoft.Compute --name EncryptionAtHost')
param encryptionAtHost bool = false

var isLinux = osType == 'Linux'

var imageReference = isLinux
  ? {
      publisher: 'Canonical'
      offer: 'ubuntu-24_04-lts'
      sku: 'server'
      version: 'latest'
    }
  : {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-smalldisk-g2'
      version: 'latest'
    }

var linuxConfiguration = {
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

// Extension: install a web server so you can verify it with run-command.
var extension = isLinux
  ? {
      publisher: 'Microsoft.Azure.Extensions'
      type: 'CustomScript'
      typeHandlerVersion: '2.1'
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "Hello from $(hostname) - AZ-104 lab 07" > /var/www/html/index.html'
    }
  : {
      publisher: 'Microsoft.Compute'
      type: 'CustomScriptExtension'
      typeHandlerVersion: '1.10'
      commandToExecute: 'powershell -ExecutionPolicy Bypass -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value (\'Hello from \' + $env:COMPUTERNAME + \' - AZ-104 lab 07\')"'
    }

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-${vmName}'
  location: location
  properties: {
    securityRules: [] // default rules only: nothing from the internet gets in
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
          // New VNets are private by default (no internet egress). The extension needs to download
          // packages, so this lab opts back in. Production answer: NAT Gateway or a firewall.
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

resource dataDisk 'Microsoft.Compute/disks@2025-01-02' = {
  name: 'disk-${vmName}-data01'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSizeGiB
  }
}

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
      encryptionAtHost: encryptionAtHost
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: 'disk-${vmName}-os'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS' // cheapest; StandardSSD_LRS or Premium_LRS for real workloads
        }
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Attach'
          caching: 'None'
          deleteOption: 'Detach'
          managedDisk: {
            id: dataDisk.id
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: isLinux ? null : adminPasswordOrKey
      linuxConfiguration: isLinux ? linuxConfiguration : null
      windowsConfiguration: isLinux
        ? null
        : {
            provisionVMAgent: true
            enableAutomaticUpdates: true
            timeZone: autoShutdownTimeZone
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
        enabled: true // managed boot diagnostics storage; lets you see the serial console/screenshot
      }
    }
  }
}

resource webServer 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = {
  parent: vm
  name: 'install-web-server'
  location: location
  properties: {
    publisher: extension.publisher
    type: extension.type
    typeHandlerVersion: extension.typeHandlerVersion
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: extension.commandToExecute
    }
  }
}

// Auto-shutdown is a DevTest Labs schedule resource with a fixed name format.
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = if (enableAutoShutdown) {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: vm.id
    notificationSettings: {
      status: empty(autoShutdownEmail) ? 'Disabled' : 'Enabled'
      timeInMinutes: 30
      emailRecipient: autoShutdownEmail
    }
  }
}

output vmName string = vm.name
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output osType string = osType
