# Lab 01: Custom RBAC role and role assignments

| | |
|---|---|
| Exam domain | Manage Azure identities and governance (20-25%) |
| Scope | Subscription (role definition) + resource group (assignments) |
| Estimated cost | $0 |
| Time | 45-60 minutes |

## Objective

- Create an Entra ID security group and a test user (Entra users and groups).
- Write a **custom role** that can start, restart, and deallocate VMs but not create or delete them.
- Assign built-in **Reader** and the custom role to the group at **resource group scope**.
- Read and interpret effective access.

## Exam skills covered

- Create users and groups; manage user and group properties
- Manage built-in Azure roles
- Assign roles at different scopes
- Interpret access assignments

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter (subscription scope): resource group + a read-only custom role + module call |
| `modules/assignments.bicep` | Starter module (RG scope): Reader assignment; you add the custom role assignment |
| `main.bicepparam` | Reads the group object ID from `AZ104_PRINCIPAL_ID` (deploy.ps1 sets it) |
| `solution/` | Reference solution (main + module) |
| `deploy.ps1` / `cleanup.ps1` | What-if, confirm, deploy / delete assignments, RG, and the custom role |

## Steps

### 1. Create the group and a test user

```powershell
$domain = az rest --method get --url https://graph.microsoft.com/v1.0/domains --query "value[?isDefault].id" -o tsv
az ad group create --display-name AZ104-Lab-Operators --mail-nickname az104labops
az ad user create --display-name "Lab Operator" --user-principal-name "lab.operator@$domain" --password "<a strong temporary password>" --force-change-password-next-sign-in true
az ad group member add --group AZ104-Lab-Operators --member-id (az ad user show --id "lab.operator@$domain" --query id -o tsv)
```

This mirrors what you did on-prem for years: put people in groups, give the group rights.

### 2. Explore built-in roles and operations

```powershell
az role definition list --name "Virtual Machine Contributor" --query "[].permissions[].actions" -o jsonc
az provider operation show --namespace Microsoft.Compute --query "resourceTypes[?name=='virtualMachines'].operations[].name" -o tsv
```

### 3. Finish the starter

Complete the TODOs in `main.bicep` and `modules/assignments.bicep`.

### 4. Deploy

```powershell
cd labs/01-rbac-custom-role
./deploy.ps1 -WhatIf
./deploy.ps1                 # looks up AZ104-Lab-Operators and asks before deploying
```

## Verify

```powershell
az role definition list --custom-role-only true --query "[].{name:roleName, scopes:assignableScopes}" -o jsonc
az role assignment list --resource-group rg-az104-lab01-rbac --query "[].{role:roleDefinitionName, principal:principalName, scope:scope}" -o table
az role assignment list --assignee "lab.operator@<your-domain>" --all --include-groups -o table
```

PowerShell (Az module):

```powershell
Get-AzRoleDefinition -Custom | Select-Object Name, AssignableScopes
Get-AzRoleAssignment -ResourceGroupName rg-az104-lab01-rbac | Select-Object DisplayName, RoleDefinitionName, Scope
```

Portal: open the resource group > **Access control (IAM) > Check access**, search for the test user, and read the effective permissions. Then try it: sign in as the test user in a private browser window and confirm you can see the resource group but cannot create anything.

## Interview talking points

- **Azure RBAC vs. Entra ID roles**: Azure RBAC controls Azure resources (subscriptions, RGs, VMs); Entra roles (Global Admin, User Admin) control the directory. You managed both sides on-prem as AD delegation vs. server admin rights.
- **Scope inheritance**: management group > subscription > resource group > resource. Assign at the narrowest scope that works.
- **Additive permissions**: Reader + custom role = union of both. Deny assignments are the exception (used by Blueprints/managed apps).
- **Why a custom role**: least privilege for a help desk or NOC team, the same idea as delegating "reset password" on an OU instead of granting Domain Admins.
- `Actions` vs. `DataActions`: management plane vs. data plane (for example reading blob contents).

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

It removes the RG-scoped role assignments, deletes the resource group, then deletes the custom role definition. The Entra group and test user stay; delete them when you no longer need them:

```powershell
az ad user delete --id "lab.operator@<your-domain>"
az ad group delete --group AZ104-Lab-Operators
```

## My notes

_Why is `assignableScopes` limited to the resource group? What happens if you try to assign the role at subscription scope?_
