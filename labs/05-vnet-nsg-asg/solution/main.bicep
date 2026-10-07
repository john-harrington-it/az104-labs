// Lab 05 - Virtual network, subnets, NSGs, and application security groups (reference solution)
// Scope: resource group. Everything in this lab is free (VNets, subnets, NSGs, ASGs have no charge).
targetScope = 'resourceGroup'

@description('Region for the network.')
param location string = resourceGroup().location

@description('Address space for the VNet.')
param vnetAddressPrefix string = '10.50.0.0/16'

@description('Web tier subnet.')
param webSubnetPrefix string = '10.50.1.0/24'

@description('App tier subnet.')
param appSubnetPrefix string = '10.50.2.0/24'

@description('Your public IP in CIDR form (for example 203.0.113.10/32) to allow SSH/RDP to the web tier. Empty = no admin rule.')
param adminSourcePrefix string = ''

// ASGs group NICs by role, so rules say "web servers" instead of a list of IPs.
// Similar idea to targeting a security group in AD instead of individual computers.
resource webAsg 'Microsoft.Network/applicationSecurityGroups@2025-07-01' = {
  name: 'asg-web'
  location: location
}

resource appAsg 'Microsoft.Network/applicationSecurityGroups@2025-07-01' = {
  name: 'asg-app'
  location: location
}

var adminRule = empty(adminSourcePrefix) ? [] : [
  {
    name: 'Allow-Admin-SSH-RDP'
    properties: {
      priority: 200
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourceAddressPrefix: adminSourcePrefix
      sourcePortRange: '*'
      destinationApplicationSecurityGroups: [
        {
          id: webAsg.id
        }
      ]
      destinationPortRanges: [
        '22'
        '3389'
      ]
    }
  }
]

resource webNsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-web'
  location: location
  properties: {
    securityRules: concat([
      {
        name: 'Allow-HTTP-HTTPS-From-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet' // service tag
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
    ], adminRule)
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-app'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-To-App-8080'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            {
              id: webAsg.id
            }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: appAsg.id
            }
          ]
          destinationPortRange: '8080'
        }
      }
      {
        // The default rule AllowVnetInBound (65000) lets every subnet talk to every other subnet.
        // This explicit deny at 4000 overrides it, so only the rule above gets through.
        name: 'Deny-All-Other-VNet-Inbound'
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
          // Private subnet: no implicit internet egress. With API 2025-07-01 this is already the
          // default for new VNets; setting it explicitly documents the intent.
          defaultOutboundAccess: false
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: appNsg.id
          }
          defaultOutboundAccess: false
          // Service endpoint: traffic to Azure Storage from this subnet stays on the Azure
          // backbone and can be allowed by the storage firewall by subnet.
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetIds object = {
  web: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-web')
  app: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-app')
}
output asgIds object = {
  web: webAsg.id
  app: appAsg.id
}
