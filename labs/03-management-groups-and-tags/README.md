# Lab 03: Management groups and tags

| | |
|---|---|
| Exam domain | Manage Azure identities and governance (20-25%) |
| Scope | Tenant (management groups, via Azure CLI) + resource group (tags, via Bicep) |
| Estimated cost | $0 (management groups, tags, NSGs, and ASGs are free) |
| Time | 45 minutes |

## Objective

- Build a small **management group** hierarchy with Azure CLI and understand where it sits (tenant root > management groups > subscriptions > resource groups > resources).
- Use Bicep to **merge** tags onto a resource group without wiping existing tags, and copy resource group tags onto resources.
- Read a tenant-scope Bicep file (`solution/management-groups.bicep`) and explain why the lab uses CLI instead.

## Exam skills covered

- Configure management groups
- Apply and manage tags on resources
- Manage resource groups and subscriptions
- Interpret a Bicep file

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: a tagged NSG. TODOs for the RG tag merge and an ASG. |
| `main.bicepparam` | Tag values |
| `solution/main.bicep` | Reference solution for the tags part |
| `solution/management-groups.bicep` | Tenant-scope version of the management group steps (read it; deploying is optional) |
| `deploy.ps1` | Deploys the tags template. `-CreateManagementGroups` also runs the CLI steps below. |
| `cleanup.ps1` | Deletes empty lab management groups and the resource group |

## Steps

### 1. Management groups (Azure CLI)

Bicep can create management groups, but only in a **tenant-scope** deployment, which needs rights at the tenant root (normally a Global Administrator with "elevate access"). The CLI only needs the default permission any user has to create a management group, so this lab uses the CLI:

```powershell
az account management-group list -o table
az account management-group create --name mg-az104-lab --display-name "AZ-104 Lab"
az account management-group create --name mg-az104-sandbox --display-name "AZ-104 Lab - Sandbox" --parent mg-az104-lab
az account management-group show --name mg-az104-lab --expand --recurse -o jsonc
```

Optional (read the note first): move your subscription under the sandbox group, look at inherited access and policy in the portal, then move it back.

```powershell
$sub = az account show --query id -o tsv
az account management-group subscription add --name mg-az104-sandbox --subscription $sub
# ...explore...
$tenantRoot = az account show --query tenantId -o tsv
az account management-group subscription add --name $tenantRoot --subscription $sub   # move back to tenant root
```

> Moving a subscription changes which policies and role assignments it inherits. On a personal study subscription that is fine. Never do it on a work subscription without a change request.

### 2. Tags (Bicep)

Complete the TODOs in `main.bicep`, then:

```powershell
cd labs/03-management-groups-and-tags
./deploy.ps1 -WhatIf
./deploy.ps1                      # or: ./deploy.ps1 -CreateManagementGroups
```

Read the what-if output for the `Microsoft.Resources/tags` resource. If you forget `union()`, what-if shows the deploy.ps1 tags being **removed**.

### 3. Tags at subscription level (CLI)

```powershell
$sub = az account show --query id -o tsv
az tag update --resource-id "/subscriptions/$sub" --operation Merge --tags environment=study
az tag list --resource-id "/subscriptions/$sub"
```

## Verify

```powershell
az group show --name rg-az104-lab03-tags --query tags
az resource list --resource-group rg-az104-lab03-tags --query "[].{name:name, tags:tags}" -o jsonc
az resource list --tag tier=web -o table
az account management-group show --name mg-az104-lab --expand -o jsonc
```

PowerShell (Az module):

```powershell
(Get-AzResourceGroup rg-az104-lab03-tags).Tags
Get-AzResource -TagName tier -TagValue web
Get-AzManagementGroup -GroupName mg-az104-lab -Expand
```

## Interview talking points

- **Hierarchy**: tenant root group > management groups (up to six levels deep) > subscriptions > resource groups > resources. Policy and RBAC assigned high up flow down, a lot like GPOs linked at the domain vs. an OU.
- **Tags do not inherit by default.** You either copy them in templates (this lab) or enforce inheritance with Azure Policy (lab 02).
- Tags drive **cost reporting** (cost analysis grouped by `costCenter`) and automation (for example, shut down everything tagged `environment=dev` at night).
- The `Microsoft.Resources/tags` resource **replaces** the tag set. `az tag update --operation Merge` merges. Knowing the difference avoids wiping a finance team's tags.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

Management groups are only deleted if they contain no subscriptions. Move your subscription back first if you did the optional step. Remove the subscription tag if you added one: `az tag update --resource-id "/subscriptions/$sub" --operation Delete --tags environment=study`.

## My notes

_What did what-if show for the tags resource with and without union()?_
