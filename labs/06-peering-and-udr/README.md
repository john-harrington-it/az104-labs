# Lab 06: Hub-and-spoke VNet peering and user-defined routes

| | |
|---|---|
| Exam domain | Implement and manage virtual networking (15-20%) |
| Scope | Resource group |
| Estimated cost | $0 (peering bills per GB transferred; this lab sends no traffic) |
| Time | 45-60 minutes |

## Objective

- Build a hub VNet and two spoke VNets with non-overlapping address spaces.
- Peer each spoke with the hub (both directions) and confirm the peerings are **Connected**.
- Add a **route table (UDR)** that sends spoke-to-spoke traffic to a network virtual appliance (NVA) IP in the hub.
- Understand why peering is **not transitive** and how hubs solve that.

## Exam skills covered

- Create and configure virtual network peering
- Configure user-defined routes
- Troubleshoot network connectivity

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: hub + two spokes, no peering, no routes. TODOs for both. |
| `main.bicepparam` | Address ranges |
| `solution/` | Reference solution (uses loops over the `spokes` array) |
| `deploy.ps1` / `cleanup.ps1` | Deploy / delete the resource group |

## Steps

1. Complete the TODOs in `main.bicep`. Use `[for (spoke, i) in spokes: {...}]` loops so adding a third spoke is a one-line change.
2. Deploy:

   ```powershell
   cd labs/06-peering-and-udr
   ./deploy.ps1 -WhatIf
   ./deploy.ps1
   ```

3. Try it: add a third spoke (`10.63.0.0/16`) to the parameters and redeploy. Read the what-if output first.

## Verify

```powershell
az network vnet peering list -g rg-az104-lab06-peering --vnet-name vnet-lab06-hub --query "[].{name:name, state:peeringState, sync:peeringSyncLevel, forwarded:allowForwardedTraffic}" -o table
az network vnet peering list -g rg-az104-lab06-peering --vnet-name vnet-lab06-spoke1 -o table
az network route-table route list -g rg-az104-lab06-peering --route-table-name rt-lab06-spokes -o table
az network vnet subnet show -g rg-az104-lab06-peering --vnet-name vnet-lab06-spoke1 -n snet-workload --query routeTable.id
```

PowerShell (Az module):

```powershell
Get-AzVirtualNetworkPeering -ResourceGroupName rg-az104-lab06-peering -VirtualNetworkName vnet-lab06-hub | Select-Object Name, PeeringState
Get-AzRouteTable -ResourceGroupName rg-az104-lab06-peering | Select-Object -ExpandProperty Routes
```

**Optional, costs a little:** to see routing in action, deploy a B1s VM into each spoke (reuse `modules/small-linux-vm.bicep` or lab 07), then:

```powershell
az network nic show-effective-route-table -g <rg> -n <nic-name> -o table
az network watcher show-next-hop -g <rg> --vm <vm-name> --source-ip <spoke1-ip> --dest-ip <spoke2-ip>
```

Next hop should be `VirtualAppliance 10.60.1.4`. Delete the VMs right after.

## Interview talking points

- **Peering is non-transitive**: spoke1 <-> hub <-> spoke2 does not mean spoke1 <-> spoke2. Fix it with an NVA/Azure Firewall in the hub plus UDRs (this lab), or Azure Virtual WAN.
- **Gateway transit**: `allowGatewayTransit` on the hub and `useRemoteGateways` on spokes let every spoke use one VPN/ExpressRoute gateway in the hub. That is how a hybrid design like your on-prem sites would connect. (The gateway itself costs money hourly, so it is not deployed here.)
- **Route selection**: longest prefix match first, then UDR over BGP over system routes. `disableBgpRoutePropagation` stops on-prem routes learned through a gateway from overriding the NVA path.
- **Address planning**: peered VNets cannot overlap, and neither can on-prem ranges you connect later. Plan ranges the way you would plan site subnets in AD Sites and Services.
- Peering works **across regions** (global peering) and across subscriptions/tenants, billed per GB in each direction.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

## My notes

_Draw the hub and spokes. Where would Azure Firewall go, and which routes would change?_
