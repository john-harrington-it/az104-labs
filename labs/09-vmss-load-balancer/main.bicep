// Lab 09 - VM scale set behind a Standard public load balancer (STARTER)
// Scope: resource group. Deploy with ./deploy.ps1 (runs what-if first).
// Costs money while it runs (small VMs + Standard LB + public IP): run cleanup.ps1 when you finish.
//
// As written, this creates the network, the public IP, and a load balancer with a frontend and an
// empty backend pool. Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'resourceGroup'

@description('Region for all resources.')
param location string = resourceGroup().location

@description('Unique DNS label for the public IP (<label>.<region>.cloudapp.azure.com).')
param dnsLabel string = 'lab09-${uniqueString(resourceGroup().id)}'

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-lab09-web'
  location: location
  properties: {
    securityRules: [
      // TODO: Standard LB is "secure by default". Add an inbound rule allowing TCP 80 from Internet,
      //       otherwise the load balancer will never reach the web servers.
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: 'vnet-lab09'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.90.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: '10.90.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
          defaultOutboundAccess: false
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2025-07-01' = {
  name: 'pip-lab09-lb'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}

var lbName = 'lbe-lab09'
var frontendName = 'fe-public'
var backendName = 'be-web'

resource lb 'Microsoft.Network/loadBalancers@2025-07-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendName
      }
    ]
    // TODO: Add an HTTP health probe on port 80, path '/'.
    // TODO: Add a load-balancing rule TCP 80 -> 80 that uses the frontend, backend pool, and probe.
    //       Reference child items with resourceId('Microsoft.Network/loadBalancers/probes', lbName, '<name>').
    //       Set disableOutboundSnat: true and add an outboundRules entry so instances can reach the internet
    //       (needed for cloud-init to install nginx, because the subnet is private).
  }
}

// TODO: Add a VM scale set (Microsoft.Compute/virtualMachineScaleSets@2025-04-01):
//       - Uniform orchestration, 2 x Standard_B1s, Ubuntu 24.04 (Canonical / ubuntu-24_04-lts / server)
//       - SSH key auth (add an @secure() param adminPublicKey; deploy.ps1 already passes AZ104_ADMIN_SECRET)
//       - customData: base64() of a cloud-init file that installs nginx
//       - NIC ipConfiguration in snet-web with loadBalancerBackendAddressPools pointing at be-web
// TODO (stretch): Add Microsoft.Insights/autoscalesettings@2022-10-01: scale out at CPU > 70%, in at < 25%.

output publicIp string = publicIp.properties.ipAddress
output lbId string = lb.id
