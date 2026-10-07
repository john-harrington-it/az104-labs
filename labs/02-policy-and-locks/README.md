# Lab 02: Azure Policy and resource locks

| | |
|---|---|
| Exam domain | Manage Azure identities and governance (20-25%) |
| Scope | Resource group |
| Estimated cost | $0 (Policy and locks are free) |
| Time | 45-60 minutes |

## Objective

- Assign built-in policies at resource group scope: **Allowed locations** (Deny), **Inherit a tag from the resource group** (Modify), and **Require a tag on resources** (Deny).
- Give a Modify policy the managed identity and role it needs.
- Put a **CanNotDelete lock** on the resource group and see it beat even Owner rights.

## Exam skills covered

- Implement and manage Azure Policy
- Configure resource locks
- Apply and manage tags on resources
- Manage resource groups

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: Allowed locations assignment. TODOs for tag policies and the lock. |
| `main.bicepparam` | Allowed regions. Keep in sync with `-Location`. |
| `solution/` | Reference solution |
| `deploy.ps1` / `cleanup.ps1` | Deploy / remove lock + assignments, then delete the RG |

## Steps

1. Look up the built-in definitions you will use:

   ```powershell
   az policy definition show --name e56962a6-4747-49cd-b67b-bf8b01975c4c --query "{name:displayName, params:parameters}" -o jsonc
   az policy definition list --query "[?policyType=='BuiltIn' && contains(displayName, 'tag')].{name:name, displayName:displayName}" -o table
   ```

2. Complete the TODOs in `main.bicep`.
3. Deploy (the script tags the resource group with `costCenter=az104-study`):

   ```powershell
   cd labs/02-policy-and-locks
   ./deploy.ps1 -WhatIf
   ./deploy.ps1
   ```

4. Wait 5-15 minutes for new assignments to take effect, then test them (next section).

## Verify

```powershell
az policy assignment list --resource-group rg-az104-lab02-governance --query "[].{name:name, effect:displayName, enforcement:enforcementMode}" -o table
az lock list --resource-group rg-az104-lab02-governance -o table

# 1. Deny by location: should FAIL with RequestDisallowedByPolicy
az network nsg create -g rg-az104-lab02-governance -n nsg-wrong-region --location westeurope

# 2. Tag inheritance: create a free NSG with NO tags in an allowed region, then read its tags.
az network nsg create -g rg-az104-lab02-governance -n nsg-inherit-test --location southcentralus
az network nsg show -g rg-az104-lab02-governance -n nsg-inherit-test --query tags

# 3. Lock: should FAIL with ScopeLocked
az group delete --name rg-az104-lab02-governance --yes

# Compliance (scans can take up to 30 minutes; trigger one now):
az policy state trigger-scan --resource-group rg-az104-lab02-governance
az policy state summarize --resource-group rg-az104-lab02-governance --query "results"
```

PowerShell (Az module):

```powershell
Get-AzPolicyAssignment -Scope (Get-AzResourceGroup rg-az104-lab02-governance).ResourceId
Get-AzResourceLock -ResourceGroupName rg-az104-lab02-governance
```

## Interview talking points

- **Policy vs. RBAC**: RBAC decides *who* can act; Policy decides *what* is allowed no matter who acts. Similar to the difference between AD delegation and Group Policy enforcement.
- **Effect order**: Disabled, then Append/Modify, then Deny, then Audit. That is why the inherit-tag policy rescues resources before the deny policy sees them.
- **Modify / DeployIfNotExists** need a managed identity plus a role, and **remediation tasks** fix existing resources.
- **Initiatives** (policy sets) group policies, like a security baseline GPO bundle.
- **Locks**: CanNotDelete vs. ReadOnly. ReadOnly can break things (for example listing storage keys is a POST and gets blocked). Locks apply to everyone, including Owners, until removed.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

The script removes the lock first (otherwise deletion fails), removes the policy assignments, then deletes the resource group.

## My notes

_What error code did each test return? How long did the policies take to start enforcing?_
