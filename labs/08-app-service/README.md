# Lab 08: App Service plan and web app

| | |
|---|---|
| Exam domain | Deploy and manage Azure compute resources (20-25%) |
| Scope | Resource group |
| Estimated cost | $0 on F1 (Free). The optional S1 step costs roughly $0.10 per hour while it exists. |
| Time | 45-60 minutes (+30 for the optional slots step) |

## Objective

- Create a Linux **App Service plan** on the Free tier and a Node.js **web app**.
- Harden it: HTTPS only, TLS 1.2, FTP disabled, system-assigned managed identity.
- Deploy the sample app in `app/` with **zip deploy**.
- Optional: scale up to **S1** to try a **deployment slot** and swap, then scale back down.

## Exam skills covered

- Provision an App Service plan; configure scaling for an App Service plan
- Create an App Service
- Configure certificates and TLS for an App Service
- Configure deployment slots for an App Service
- Configure networking settings and backup for an App Service (talking points)

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: Free Linux plan + web app. TODOs for hardening, identity, FTP, slots. |
| `main.bicepparam` | Runtime stack |
| `app/` | Tiny Node.js app (`server.js`) that prints the instance and slot name |
| `solution/` | Reference solution with an F1/B1/S1 switch and a conditional staging slot |
| `deploy.ps1` / `cleanup.ps1` | Deploy (`-DeployApp` also zips and deploys `app/`) / delete the resource group |

## Steps

1. Check the runtime list: `az webapp list-runtimes --os linux -o table`. Update `linuxFxVersion` if `NODE|22-lts` is no longer offered.
2. Complete the TODOs in `main.bicep`.
3. Deploy infrastructure and the app:

   ```powershell
   cd labs/08-app-service
   ./deploy.ps1 -WhatIf
   ./deploy.ps1 -DeployApp
   ```

4. Browse to the URL from the outputs.
5. **Optional (costs money): slots.**

   ```powershell
   ./deploy.ps1 -Solution -Sku S1 -DeployApp
   $app = az webapp list -g rg-az104-lab08-appservice --query "[0].name" -o tsv
   Compress-Archive -Path ./app/* -DestinationPath ./app.zip -Force
   az webapp deploy -g rg-az104-lab08-appservice -n $app --slot staging --src-path ./app.zip --type zip
   # browse https://<app>-staging.azurewebsites.net, then swap:
   az webapp deployment slot swap -g rg-az104-lab08-appservice -n $app --slot staging --target-slot production
   ./deploy.ps1 -Solution -Sku F1      # scale back down (delete the slot first if the downgrade is refused: az webapp deployment slot delete ...)
   ```

   Note: the `LAB_SLOT_NAME` app setting swaps with the code unless you mark it as a **slot setting**. Try `az webapp config appsettings set ... --slot-settings LAB_SLOT_NAME=staging` and swap again.

## Verify

```powershell
$app = az webapp list -g rg-az104-lab08-appservice --query "[0].name" -o tsv
az webapp show -g rg-az104-lab08-appservice -n $app --query "{state:state, httpsOnly:httpsOnly, host:defaultHostName, identity:identity.type}" -o jsonc
az webapp config show -g rg-az104-lab08-appservice -n $app --query "{tls:minTlsVersion, ftps:ftpsState, stack:linuxFxVersion}" -o jsonc
az appservice plan show -g rg-az104-lab08-appservice -n asp-lab08 --query "{sku:sku.name, workers:sku.capacity}" -o jsonc
curl.exe -s "https://$app.azurewebsites.net"
curl.exe -sI "http://$app.azurewebsites.net"     # expect a redirect to https
```

PowerShell (Az module):

```powershell
Get-AzWebApp -ResourceGroupName rg-az104-lab08-appservice | Select-Object Name, State, HttpsOnly, DefaultHostName
```

## Interview talking points

- **Plan vs. app**: the plan is the server farm you pay for (size, instance count); apps share it. Scale **up** = bigger tier; scale **out** = more instances (manual on Basic, autoscale on Standard+).
- **Tiers**: Free/Shared (no SLA, no custom TLS, no Always On), Basic (custom domains/TLS, manual scale), Standard (slots, autoscale, backups), Premium (more slots, VNet features, bigger SKUs).
- **Slots**: zero-downtime releases with warm-up and instant rollback by swapping back. Slot-sticky settings stay with the slot.
- **Custom domains and TLS**: verify with a CNAME/TXT record, then bind a free App Service managed certificate or your own. Same idea as managing certificates for Exchange or NetScaler on-prem.
- **Networking**: VNet integration for outbound to private resources; private endpoints or access restrictions for inbound.
- **Managed identity** removes secrets from app settings, the same goal as gMSAs on-prem.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
Remove-Item ./app.zip -ErrorAction SilentlyContinue
```

## My notes

_What happened to LAB_SLOT_NAME during the swap, before and after you made it a slot setting?_
