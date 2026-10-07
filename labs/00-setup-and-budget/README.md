# Lab 00: Setup and a budget alert

**Do this lab first.** It sets up your tools and puts a cost alarm on the subscription before you deploy anything that bills.

| | |
|---|---|
| Exam domain | Manage Azure identities and governance (20-25%) |
| Scope | Subscription |
| Estimated cost | $0 (budgets are free) |
| Time | 30-45 minutes |

## Objective

- Install and sign in to the tools every other lab uses.
- Deploy a monthly **budget** with email alerts at 50% and 80% of actual spend and at 100% of forecast spend.
- Learn the deploy loop used in every lab: **edit Bicep, run what-if, confirm, deploy, verify, clean up**.

## Exam skills covered

- Manage costs by using alerts, budgets, and Azure Advisor recommendations
- Manage subscriptions
- Deploy resources by using an Azure Resource Manager template or a Bicep file

## Files

| File | What it is |
|---|---|
| `main.bicep` | Your starter. Deploys a budget with one alert. Has `// TODO:` gaps. |
| `main.bicepparam` | Parameters for the starter. Reads your email from `AZ104_ALERT_EMAIL`. |
| `solution/` | Reference solution. Look only after you try. |
| `deploy.ps1` | What-if, confirm, deploy (subscription scope). |
| `cleanup.ps1` | Deletes the budget. You normally **keep** it. |

## Steps

### 1. Install the tools

| Tool | Install | Check |
|---|---|---|
| Azure CLI | https://aka.ms/installazurecli | `az version` |
| Bicep CLI | `az bicep install` | `az bicep version` |
| PowerShell 7 | https://aka.ms/powershell | `$PSVersionTable.PSVersion` |
| VS Code + Bicep extension | Extensions: "Bicep" (Microsoft) | Red squiggles appear in `.bicep` files |
| Az PowerShell (optional) | `Install-Module Az -Scope CurrentUser` | `Get-Module Az -ListAvailable` |

### 2. Sign in and pick the subscription

```powershell
az login
az account list --output table
az account set --subscription "<your subscription name or ID>"
az account show --query "{name:name, id:id, user:user.name}" --output table
```

Make sure this is your personal study subscription, never an employer's.

### 3. Register the resource providers the labs use

New subscriptions register most providers on first use, but doing it up front avoids confusing errors later:

```powershell
'Microsoft.Compute','Microsoft.Network','Microsoft.Storage','Microsoft.Web','Microsoft.Insights',
'Microsoft.OperationalInsights','Microsoft.RecoveryServices','Microsoft.DevTestLab',
'Microsoft.Consumption','Microsoft.CostManagement','Microsoft.PolicyInsights','Microsoft.Management' |
    ForEach-Object { az provider register --namespace $_ }
az provider list --query "[?registrationState=='Registered'].namespace" --output table
```

### 4. Finish the starter

Open `main.bicep`. Complete the TODOs (two more notifications and one more output). Hover over properties in VS Code to see the allowed values.

### 5. Deploy

```powershell
cd labs/00-setup-and-budget
./deploy.ps1 -AlertEmail you@yourdomain.com -WhatIf   # preview only
./deploy.ps1 -AlertEmail you@yourdomain.com           # what-if, then asks before deploying
```

Your email is passed through an environment variable for this run only. It is never written to the repo.

## Verify

```powershell
az consumption budget show --budget-name budget-az104-labs --query "{amount:amount, timeGrain:timeGrain, notifications:notifications}" --output json
az consumption budget list --output table
```

PowerShell (Az module):

```powershell
Get-AzConsumptionBudget -Name budget-az104-labs
```

In the portal: **Cost Management > Budgets**. You should see three alert conditions.

Also check **Cost Management > Cost analysis** once a day while you work through the labs.

## Interview talking points

Be ready to explain these once you have done the lab:

- A budget **alerts**, it does not **stop** spending. To actually cap spend you need a spending limit (free trial / credit offers) or automation through an action group.
- The difference between **Actual** and **Forecasted** thresholds, and why forecast alerts are the early warning.
- How you would roll budgets out per subscription or per resource group for departments, similar to chargeback you may have reported on for storage or Citrix capacity on-prem.
- Azure Advisor's cost recommendations (right-size or shut down idle VMs) as the next step after a budget.

## Cleanup

Keep the budget while you study. It costs nothing. If you really want to remove it:

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

## My notes

_Write what you learned, what broke, and how you fixed it._
