# Lab 05: Virtual network, subnets, NSGs, and application security groups

| | |
|---|---|
| Exam domain | Implement and manage virtual networking (15-20%) |
| Scope | Resource group |
| Estimated cost | $0 (VNets, subnets, NSGs, and ASGs are free) |
| Time | 45-60 minutes |

## Objective

- Build a two-tier VNet (web and app subnets) with **private subnets** (no implicit internet egress).
- Write NSG rules that target **application security groups** instead of IP addresses.
- Override the default `AllowVnetInBound` rule so the app tier only accepts traffic from the web tier on 8080.
- Add a **service endpoint** for Azure Storage.

## Exam skills covered

- Create and configure virtual networks and subnets
- Create and configure NSGs and application security groups
- Evaluate effective security rules in NSGs
- Configure service endpoints for Azure PaaS

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: VNet + web subnet + web NSG + web ASG. TODOs for the app tier. |
| `main.bicepparam` | Address ranges |
| `solution/` | Reference solution |
| `deploy.ps1` / `cleanup.ps1` | Deploy / delete the resource group |

## Steps

1. Sketch the design on paper first: VNet `10.50.0.0/16`, `snet-web 10.50.1.0/24`, `snet-app 10.50.2.0/24`. Azure reserves 5 addresses per subnet (first four and last). How many usable IPs does a /24 have?
2. Complete the TODOs in `main.bicep`.
3. Deploy:

   ```powershell
   cd labs/05-vnet-nsg-asg
   ./deploy.ps1 -WhatIf
   ./deploy.ps1
   ```

## Verify

```powershell
az network vnet show -g rg-az104-lab05-network -n vnet-lab05 --query "{space:addressSpace.addressPrefixes, subnets:subnets[].{name:name, prefix:addressPrefix, nsg:networkSecurityGroup.id, private:defaultOutboundAccess, endpoints:serviceEndpoints[].service}}" -o jsonc
az network nsg rule list -g rg-az104-lab05-network --nsg-name nsg-app --include-default -o table
az network asg list -g rg-az104-lab05-network -o table
```

PowerShell (Az module):

```powershell
Get-AzNetworkSecurityGroup -ResourceGroupName rg-az104-lab05-network -Name nsg-app | Select-Object -ExpandProperty SecurityRules | Format-Table Name, Priority, Access, Direction
```

**Effective rules** need a NIC. After lab 07 you can deploy a VM into `snet-web` (or reuse lab 07's NIC) and run:

```powershell
az network nic list-effective-nsg -g <rg> -n <nic-name>
```

Then use **Network Watcher > IP flow verify** in the portal to test "can 10.50.1.4 reach 10.50.2.4 on 8080?"

## Interview talking points

- **NSG processing**: lowest priority number wins; first match stops evaluation. Default rules (65000+) allow VNet-to-VNet and Azure Load Balancer probes and deny everything else from the internet.
- **NSG on subnet vs. NIC**: both are evaluated (inbound: subnet then NIC). Subnet-level is easier to manage, like a perimeter firewall vs. Windows Firewall on each server.
- **ASGs** let rules say "web servers to app servers" and keep working as servers are added. Same idea as using AD groups instead of individual accounts in ACLs.
- **Private subnets**: new VNets (API 2025-07-01 and later) no longer give VMs implicit internet egress. Plan explicit outbound with NAT Gateway, a load balancer outbound rule, or a firewall.
- **Service endpoint vs. private endpoint**: a service endpoint keeps traffic on the backbone and lets the PaaS firewall trust the subnet; a private endpoint gives the PaaS resource a private IP in your VNet (and needs private DNS).

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

## My notes

_Why does nsg-app need the explicit deny at 4000? What would happen without it?_
