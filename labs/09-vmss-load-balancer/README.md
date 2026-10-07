# Lab 09: VM scale set behind a Standard load balancer

| | |
|---|---|
| Exam domain | Implement and manage virtual networking (15-20%) + Deploy and manage Azure compute resources (20-25%) |
| Scope | Resource group |
| Estimated cost | Roughly $0.05 per hour (2 x B1s, Standard load balancer, Standard public IP). Clean up the same session. |
| Time | 60-90 minutes |

## Objective

- Deploy a **Standard public load balancer** with a frontend IP, backend pool, **health probe**, load-balancing rule, and **outbound rule**.
- Put a **Virtual Machine Scale Set** (2 x Ubuntu with nginx via cloud-init) in the backend pool.
- Watch requests spread across instances, then break one instance and watch the probe take it out.
- Add CPU-based **autoscale**.

## Exam skills covered

- Configure an internal or public load balancer
- Troubleshoot load balancing
- Configure public IP addresses
- Deploy and configure Azure Virtual Machine Scale Sets
- Deploy virtual machines to availability zones and availability sets (talking points)

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: VNet, NSG (no rules yet), Standard public IP, LB with frontend + empty pool. TODOs for probe, rules, VMSS, autoscale. |
| `main.bicepparam` | Starter parameters (add the SSH key parameter when you add the scale set) |
| `solution/` | Reference solution |
| `deploy.ps1` / `cleanup.ps1` | Deploy (reads your SSH public key) / delete the resource group |

## Steps

1. Complete the TODOs in `main.bicep`. Deploy after each TODO to see what changes (what-if makes this easy).
2. Deploy:

   ```powershell
   cd labs/09-vmss-load-balancer
   ./deploy.ps1 -WhatIf
   ./deploy.ps1
   ```

3. Wait 3-5 minutes for cloud-init to install nginx, then hit the frontend repeatedly:

   ```powershell
   $ip = az network public-ip show -g rg-az104-lab09-lb -n pip-lab09-lb --query ipAddress -o tsv
   1..10 | ForEach-Object { (curl.exe -s "http://$ip") -replace '<[^>]+>', ' ' }
   ```

4. Break one instance and watch the health probe remove it:

   ```powershell
   az vmss list-instances -g rg-az104-lab09-lb -n vmss-lab09 --query "[].instanceId" -o tsv
   az vmss run-command invoke -g rg-az104-lab09-lb -n vmss-lab09 --instance-id 0 --command-id RunShellScript --scripts "sudo systemctl stop nginx"
   ```

5. Scale manually, then let autoscale take over (solution):

   ```powershell
   az vmss scale -g rg-az104-lab09-lb -n vmss-lab09 --new-capacity 3
   ```

## Verify

```powershell
az network lb show -g rg-az104-lab09-lb -n lbe-lab09 --query "{sku:sku.name, probes:probes[].{name:name, port:port}, rules:loadBalancingRules[].name, outbound:outboundRules[].name}" -o jsonc
az network lb address-pool show -g rg-az104-lab09-lb --lb-name lbe-lab09 -n be-web --query "backendIPConfigurations[].id" -o tsv
az vmss list-instances -g rg-az104-lab09-lb -n vmss-lab09 -o table
az monitor metrics list --resource (az network lb show -g rg-az104-lab09-lb -n lbe-lab09 --query id -o tsv) --metric DipAvailability --interval PT1M -o table
az monitor autoscale show -g rg-az104-lab09-lb -n autoscale-vmss-lab09 -o jsonc
```

Portal: **Load balancer > Insights** shows probe health per instance.

PowerShell (Az module):

```powershell
Get-AzLoadBalancer -ResourceGroupName rg-az104-lab09-lb -Name lbe-lab09 | Select-Object -ExpandProperty Probes
Get-AzVmssVM -ResourceGroupName rg-az104-lab09-lb -VMScaleSetName vmss-lab09
```

## Interview talking points

- **Standard vs. Basic**: Basic load balancer and Basic public IPs were retired on 30 September 2025. Standard is **secure by default** (you need an NSG allow rule), zone-aware, and has an SLA.
- **Troubleshooting order** when the frontend does not answer: NSG allows the port? Probe healthy (DipAvailability metric)? App listening on the backend port? Outbound working for package installs?
- **Outbound connectivity**: explicit outbound rules (this lab), NAT Gateway (preferred at scale), or instance public IPs. Default outbound access is being retired for new VNets.
- **Load balancer vs. Application Gateway vs. Front Door vs. Traffic Manager**: Layer 4 regional, Layer 7 regional with WAF, Layer 7 global, DNS-based global. Same layering as NetScaler vs. a plain L4 VIP.
- **VMSS Uniform vs. Flexible** orchestration; autoscale rules with cooldowns; availability zones vs. availability sets.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

## My notes

_What did DipAvailability show after you stopped nginx on one instance? How long until the LB stopped sending traffic to it?_
