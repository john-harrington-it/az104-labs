# Lab 10: Azure Monitor: Log Analytics, diagnostic settings, and alerts

| | |
|---|---|
| Exam domain | Monitor and maintain Azure resources (10-15%) |
| Scope | Resource group |
| Estimated cost | A few cents: ingestion is capped at 0.1 GB/day; a metric alert is about $0.10 per month, prorated; activity log alerts are free |
| Time | 60 minutes |

## Objective

- Create a **Log Analytics workspace** with a daily ingestion cap.
- Send storage **resource logs and metrics** to it with a **diagnostic setting**.
- Create an **action group** (email), a **metric alert**, and an **activity log alert**.
- Generate traffic, fire the alerts, and query the logs with **KQL**.

## Exam skills covered

- Interpret metrics in Azure Monitor
- Configure log settings in Azure Monitor
- Query and analyze logs in Azure Monitor
- Set up alert rules, action groups, and alert processing rules in Azure Monitor
- Configure and interpret monitoring of VMs, storage accounts, and networks by using Azure Monitor Insights (talking points)

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: workspace, storage account, container, action group. TODOs for the diagnostic setting and alerts. |
| `main.bicepparam` | Reads your email (`AZ104_ALERT_EMAIL`) and object ID (`AZ104_PRINCIPAL_ID`) |
| `solution/` | Reference solution |
| `deploy.ps1` / `cleanup.ps1` | Deploy (`-AlertEmail` required) / delete the resource group |

## Steps

1. Complete the TODOs in `main.bicep`.
2. Deploy:

   ```powershell
   cd labs/10-monitoring-and-alerts
   ./deploy.ps1 -AlertEmail you@yourdomain.com -WhatIf
   ./deploy.ps1 -AlertEmail you@yourdomain.com
   ```

   You get an email saying you were added to the action group.

3. Generate traffic (more than 50 transactions in 5 minutes):

   ```powershell
   $sa = az storage account list -g rg-az104-lab10-monitor --query "[0].name" -o tsv
   "x" | Out-File ping.txt
   1..40 | ForEach-Object { az storage blob upload --account-name $sa -c monitored -n "ping-$_.txt" -f ping.txt --auth-mode login --overwrite --only-show-errors | Out-Null }
   az storage blob list --account-name $sa -c monitored --auth-mode login -o table
   ```

4. Fire the activity log alert:

   ```powershell
   az storage account keys renew -g rg-az104-lab10-monitor -n $sa --key key2
   ```

5. Wait 5-10 minutes for logs to arrive and the alerts to fire, then check your email and run the queries below.
6. Stretch: create an **alert processing rule** that suppresses notifications during a maintenance window:

   ```powershell
   az monitor alert-processing-rule create -g rg-az104-lab10-monitor -n apr-lab10-maintenance --rule-type RemoveAllActionGroups --scopes (az group show -n rg-az104-lab10-monitor --query id -o tsv) --description "Lab 10 maintenance window"
   ```

## Verify

```powershell
$ws = az monitor log-analytics workspace list -g rg-az104-lab10-monitor --query "[0].customerId" -o tsv
az monitor diagnostic-settings list --resource (az storage account show -n $sa --query id -o tsv)/blobServices/default -o jsonc
az monitor metrics alert list -g rg-az104-lab10-monitor -o table
az monitor activity-log alert list -g rg-az104-lab10-monitor -o table
az monitor metrics list --resource (az storage account show -n $sa --query id -o tsv) --metric Transactions --interval PT5M --aggregation Total -o table

# KQL (the CLI may ask to install the log-analytics extension)
az monitor log-analytics query -w $ws --analytics-query "StorageBlobLogs | summarize count() by OperationName | order by count_ desc" -o table
az monitor log-analytics query -w $ws --analytics-query "StorageBlobLogs | where TimeGenerated > ago(1h) | project TimeGenerated, OperationName, StatusText, CallerIpAddress, Uri | take 20" -o table
```

PowerShell (Az module):

```powershell
Get-AzMetricAlertRuleV2 -ResourceGroupName rg-az104-lab10-monitor
Invoke-AzOperationalInsightsQuery -WorkspaceId $ws -Query 'StorageBlobLogs | summarize count() by OperationName'
```

Portal: **Monitor > Alerts** shows fired alerts; **Storage account > Insights** shows the built-in workbook.

## Interview talking points

- **Metrics vs. logs**: metrics are lightweight numbers (near real-time, 93 days); logs are detailed records you query with KQL in Log Analytics. Diagnostic settings are how resource logs get there.
- **Alert types**: metric, log search, activity log, and service/resource health alerts. **Action groups** are reusable "who and how to notify" (email, SMS, webhook, Logic App, ITSM). **Alert processing rules** suppress or redirect alerts, for example during patch windows.
- **Cost control**: daily cap, retention settings, and only collecting the categories you need.
- **On-prem comparison**: the same job SCOM, PRTG, or event log forwarding did, plus KQL instead of digging through event viewers. This ties directly to AIOps work: KQL output is exactly the kind of signal an anomaly-detection agent consumes.
- **VM monitoring**: Azure Monitor Agent with data collection rules (DCRs) and VM Insights; **Network Watcher** for connection troubleshooting and connection monitor.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
Remove-Item ping.txt -ErrorAction SilentlyContinue
```

If you created the alert processing rule, deleting the resource group removes it too.

## My notes

_Paste the KQL query you found most useful and what it showed._
