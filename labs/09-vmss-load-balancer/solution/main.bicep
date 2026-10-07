// Lab 09 - VM scale set behind a Standard public load balancer, with autoscale (reference solution)
// Scope: resource group. Costs money while it runs (2 small VMs + Standard LB + Standard public IP):
// run cleanup.ps1 when you finish. Basic LB and Basic public IPs were retired on 30 Sep 2025.
targetScope = 'resourceGroup'

@description('Region for all resources.')
param location string = resourceGroup().location

@description('Scale set instance size.')
param vmSize string = 'Standard_B1s'

@description('Starting instance count.')
@minValue(1)
@maxValue(3)
param instanceCount int = 2

@description('Local admin user name.')
param adminUsername string = 'labadmin'

@description('SSH public key. deploy.ps1 fills this in; never commit it.')
@secure()
param adminPublicKey string

@description('Unique DNS label for the public IP (<label>.<region>.cloudapp.azure.com).')
param dnsLabel string = 'lab09-${uniqueString(resourceGroup().id)}'

// cloud-init: install nginx and show which instance answered, so you can watch the LB spread requests.
var cloudInit = '''
#cloud-config
package_update: true
packages:
  - nginx
runcmd:
  - bash -c 'echo "<h1>AZ-104 lab 09</h1><p>Answered by $(hostname)</p>" > /var/www/html/index.html'
'''

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: 'nsg-lab09-web'
  location: location
  properties: {
    securityRules: [
      {
        // Standard LB is secure by default: without an NSG allow rule, nothing reaches the backend.
        // Health probes come from the AzureLoadBalancer tag, which the default rules already allow.
        name: 'Allow-HTTP-From-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
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
          defaultOutboundAccess: false // egress goes through the LB outbound rule instead
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
    publicIPAllocationMethod: 'Static' // Standard SKU is always static
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}

var lbName = 'lbe-lab09'
var frontendName = 'fe-public'
var backendName = 'be-web'
var probeName = 'probe-http'

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
    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          probeThreshold: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-http'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, probeName)
          }
          loadDistribution: 'Default' // 5-tuple hash; SourceIP = "session persistence"
          idleTimeoutInMinutes: 4
          enableTcpReset: true
          disableOutboundSnat: true // outbound is handled by the explicit outbound rule below
        }
      }
    ]
    outboundRules: [
      {
        name: 'outbound-all'
        properties: {
          protocol: 'All'
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, frontendName)
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, backendName)
          }
          allocatedOutboundPorts: 1024
          idleTimeoutInMinutes: 4
          enableTcpReset: true
        }
      }
    ]
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2025-04-01' = {
  name: 'vmss-lab09'
  location: location
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    orchestrationMode: 'Uniform'
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
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
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }
      osProfile: {
        computerNamePrefix: 'web'
        adminUsername: adminUsername
        customData: base64(cloudInit)
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
        networkInterfaceConfigurations: [
          {
            name: 'nic-web'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: vnet.properties.subnets[0].id
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lb.name, backendName)
                      }
                    ]
                  }
                }
              ]
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
}

// Autoscale: add an instance when average CPU > 70% for 5 minutes, remove one when < 25% for 10.
resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: 'autoscale-vmss-lab09'
  location: location
  properties: {
    enabled: true
    targetResourceUri: vmss.id
    profiles: [
      {
        name: 'cpu-based'
        capacity: {
          minimum: '1'
          maximum: '3'
          default: string(instanceCount)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 25
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

output publicIp string = publicIp.properties.ipAddress
output url string = 'http://${publicIp.properties.dnsSettings.fqdn}'
output vmssName string = vmss.name
