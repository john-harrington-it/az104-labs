// Lab 06 - Hub-and-spoke VNet peering + user-defined routes (reference solution)
// Scope: resource group. VNets, peerings, and route tables are free; peering bills only for
// data that crosses it, and this lab sends none unless you add VMs.
targetScope = 'resourceGroup'

@description('Region for all VNets.')
param location string = resourceGroup().location

@description('Hub address space. The hub would hold shared services: firewall/NVA, VPN gateway, DNS.')
param hubAddressPrefix string = '10.60.0.0/16'

@description('Spoke VNets (workloads).')
param spokes array = [
  {
    name: 'vnet-lab06-spoke1'
    addressPrefix: '10.61.0.0/16'
    subnetPrefix: '10.61.1.0/24'
  }
  {
    name: 'vnet-lab06-spoke2'
    addressPrefix: '10.62.0.0/16'
    subnetPrefix: '10.62.1.0/24'
  }
]

@description('Private IP of the (imaginary) network virtual appliance / firewall in the hub. Nothing is deployed there; the route still shows how traffic would be steered.')
param nvaPrivateIp string = '10.60.1.4'

resource hub 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: 'vnet-lab06-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-nva'
        properties: {
          addressPrefix: cidrSubnet(hubAddressPrefix, 24, 1) // 10.60.1.0/24
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

// One route table shared by both spokes: send traffic for ANY spoke range to the hub NVA.
// Peering is not transitive, so spoke1 cannot reach spoke2 directly; routing through an NVA
// (or Azure Firewall) in the hub is the standard fix.
resource spokeRoutes 'Microsoft.Network/routeTables@2025-07-01' = {
  name: 'rt-lab06-spokes'
  location: location
  properties: {
    disableBgpRoutePropagation: true // ignore routes learned from a VPN/ExpressRoute gateway
    routes: [
      for spoke in spokes: {
        name: 'to-${spoke.name}-via-nva'
        properties: {
          addressPrefix: spoke.addressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaPrivateIp
        }
      }
    ]
  }
}

resource spokeVnets 'Microsoft.Network/virtualNetworks@2025-07-01' = [
  for spoke in spokes: {
    name: spoke.name
    location: location
    properties: {
      addressSpace: {
        addressPrefixes: [
          spoke.addressPrefix
        ]
      }
      subnets: [
        {
          name: 'snet-workload'
          properties: {
            addressPrefix: spoke.subnetPrefix
            defaultOutboundAccess: false
            routeTable: {
              id: spokeRoutes.id
            }
          }
        }
      ]
    }
  }
]

// Peering is created from BOTH sides. Each side is its own resource.
resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-07-01' = [
  for (spoke, i) in spokes: {
    parent: hub
    name: 'peer-hub-to-${spoke.name}'
    properties: {
      remoteVirtualNetwork: {
        id: spokeVnets[i].id
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false // set true if the hub had a VPN gateway to share with spokes
      useRemoteGateways: false
    }
  }
]

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-07-01' = [
  for (spoke, i) in spokes: {
    parent: spokeVnets[i]
    name: 'peer-${spoke.name}-to-hub'
    properties: {
      remoteVirtualNetwork: {
        id: hub.id
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true // accept traffic the hub NVA forwards from the other spoke
      allowGatewayTransit: false
      useRemoteGateways: false // would be true to use the hub's VPN gateway (needs one deployed)
    }
  }
]

output hubId string = hub.id
output spokeIds array = [for (spoke, i) in spokes: spokeVnets[i].id]
output routeTableId string = spokeRoutes.id
output hubPeeringNames array = [for (spoke, i) in spokes: hubToSpoke[i].name]
output spokePeeringNames array = [for (spoke, i) in spokes: spokeToHub[i].name]
