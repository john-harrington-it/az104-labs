// Lab 05 - Virtual network, subnets, NSGs, and application security groups (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first). Everything here is free.
//
// As written, this creates the VNet with a web subnet protected by an NSG that allows HTTP/HTTPS
// to the web ASG. Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for the network.')
param location string = resourceGroup().location

@description('Address space for the VNet.')
param vnetAddressPrefix string = '10.50.0.0/16'

@description('Web tier subnet.')
param webSubnetPrefix string = '10.50.1.0/24'

@description('App tier subnet.')
param appSubnetPrefix string = '10.50.2.0/24'

resource webAsg 'Microsoft.Network/applicationSecurityGroups@2025-07-01' = {
  name: 'asg-web'
  location: location
}

resource appAsg 'Microsoft.Network/applicationSecurityGroups@2025-07-01' = {
  name: 'asg-app'
  location: location
}


resource webNsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-web'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-HTTPS-From-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: webAsg.id
            }
          ]
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
      // TODO (stretch): Allow SSH/RDP only from your own public IP (param adminSourcePrefix).
    ]
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-app'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-8080-Web-To-App'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [ { id: webAsg.id } ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [ { id: appAsg.id } ]
          destinationPortRange: '8080'
        }
      }
      {
        name: 'Deny-All-VNet-Inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: 'vnet-lab05'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: webNsg.id
          }
          defaultOutboundAccess: false
        }
      }
            {
        name: 'snet-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: { id: appNsg.id }
          defaultOutboundAccess: false
          serviceEndpoints: [ { service: 'Microsoft.Storage' } ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
