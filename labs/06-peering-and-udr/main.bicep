// Lab 06 - Hub-and-spoke VNet peering + user-defined routes (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first). Everything here is free.
//
// As written, this creates a hub VNet and two spoke VNets that cannot talk to each other.
// Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for all VNets.')
param location string = resourceGroup().location

@description('Hub address space.')
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

// TODO: Add a route table (Microsoft.Network/routeTables@2025-07-01) named rt-lab06-spokes with one route
//       per spoke: addressPrefix = spoke range, nextHopType 'VirtualAppliance', nextHopIpAddress '10.60.1.4'.
//       Set disableBgpRoutePropagation to true. Make the NVA IP a parameter.

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
            // TODO: Associate the route table here: routeTable: { id: <routeTable>.id }
          }
        }
      ]
    }
  }
]

// TODO: Peer the hub with each spoke. You need TWO resources per pair
//       (Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-07-01):
//         hub -> spoke   (parent: hub,           remoteVirtualNetwork: spokeVnets[i])
//         spoke -> hub   (parent: spokeVnets[i], remoteVirtualNetwork: hub)
//       Use a loop: [for (spoke, i) in spokes: { ... }]. Set allowForwardedTraffic: true on both sides.

output hubId string = hub.id
output spokeIds array = [for (spoke, i) in spokes: spokeVnets[i].id]
