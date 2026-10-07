# Lab 11: Recovery Services vault and VM backup

| | |
|---|---|
| Exam domain | Monitor and maintain Azure resources (10-15%) |
| Scope | Resource group |
| Estimated cost | A B1s VM (about $0.01 per hour) plus Azure Backup's protected-instance fee and snapshot storage while protected. Well under $1 if you clean up the same day. |
| Time | 60-90 minutes (the first backup can take 30+ minutes) |

## Objective

- Create a **Recovery Services vault** (LRS storage to keep costs down).
- Create an **enhanced (V2) backup policy**: daily backup, 7-day retention, 2-day instant restore.
- **Protect a VM**, run an on-demand backup, and walk through **file-level and VM restore** options.
- Understand **soft delete** and why this lab disables it only to clean up the same day.

## Exam skills covered

- Create a Recovery Services vault
- Create an Azure Backup vault (talking points: which workloads use which vault)
- Create and configure a backup policy
- Perform backup and restore operations by using Azure Backup
- Configure and interpret reports and alerts for backups
- Configure Azure Site Recovery for Azure resources (talking points)

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: vault + a small VM from `modules/small-linux-vm.bicep`. TODOs for the policy and protection. |
| `main.bicepparam` | Reads your SSH public key from `AZ104_ADMIN_SECRET` (deploy.ps1 sets it) |
| `solution/` | Reference solution |
| `deploy.ps1` | Deploy (reads your SSH public key) |
| `cleanup.ps1` | Disables soft delete, stops protection and deletes backup data, then deletes the resource group |

## Steps

1. Complete the TODOs in `main.bicep`.
2. Deploy:

   ```powershell
   cd labs/11-backup-recovery-vault
   ./deploy.ps1 -WhatIf
   ./deploy.ps1
   $vault = az backup vault list -g rg-az104-lab11-backup --query "[0].name" -o tsv
   ```

3. Run an on-demand backup and watch the job:

   ```powershell
   $item = az backup item list -g rg-az104-lab11-backup -v $vault --backup-management-type AzureIaasVM --query "[0]" -o json | ConvertFrom-Json
   $retain = (Get-Date).AddDays(7).ToString('dd-MM-yyyy')
   az backup protection backup-now -g rg-az104-lab11-backup -v $vault --container-name $item.properties.containerName --item-name $item.name --backup-management-type AzureIaasVM --retain-until $retain
   az backup job list -g rg-az104-lab11-backup -v $vault -o table
   ```

4. When the job finishes, list recovery points and explore restore options in the portal (**Vault > Backup items > vm-lab11 > Restore VM / File Recovery**). Restoring to a new VM or restoring disks adds resources to the resource group; cleanup removes them.

   ```powershell
   az backup recoverypoint list -g rg-az104-lab11-backup -v $vault --container-name $item.properties.containerName --item-name $item.name --backup-management-type AzureIaasVM -o table
   ```

## Verify

```powershell
az backup vault show -g rg-az104-lab11-backup -n $vault --query "{sku:sku.name, redundancy:properties.redundancySettings.standardTierStorageRedundancy}" -o jsonc
az backup vault backup-properties show -g rg-az104-lab11-backup -n $vault -o jsonc
az backup policy list -g rg-az104-lab11-backup -v $vault --query "[].{name:name, type:properties.policyType}" -o table
az backup item list -g rg-az104-lab11-backup -v $vault --backup-management-type AzureIaasVM --query "[].{vm:properties.friendlyName, status:properties.protectionStatus, lastBackup:properties.lastBackupTime}" -o table
```

PowerShell (Az module):

```powershell
$v = Get-AzRecoveryServicesVault -ResourceGroupName rg-az104-lab11-backup
Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $v.ID
Get-AzRecoveryServicesBackupJob -VaultId $v.ID
```

Portal: **Vault > Backup reports / Backup alerts** (reports need a diagnostic setting to a Log Analytics workspace, like lab 10).

## Interview talking points

Tie these to your Veeam experience:

| Veeam concept | Azure Backup equivalent |
|---|---|
| Backup repository | Recovery Services vault (LRS/ZRS/GRS storage) |
| Backup job + schedule + retention | Backup policy assigned to protected items |
| Storage snapshot / instant VM recovery | Instant restore snapshots (instantRpRetentionRangeInDays) |
| Hardened / immutable repository | Vault immutability + soft delete + multi-user authorization |
| File-level restore | File Recovery (mounts the recovery point as a drive) |
| Veeam Replication / DR | Azure Site Recovery (replication + failover to another region) |

- **Recovery Services vault vs. Backup vault**: RSV covers Azure VMs, SQL/SAP HANA in VMs, Azure Files, MARS agent; the newer Backup vault covers Azure Disks, Blobs, PostgreSQL, AKS.
- **Enhanced policy** is required for Trusted Launch VMs and supports multiple backups per day.
- **Soft delete** protects against ransomware deleting backups. This lab disables it **only** to clean up the same day. In production keep it on (or make it always-on).
- **Backup vs. Site Recovery**: backup = restore data to a point in time; ASR = keep a replica ready to fail over with a low RPO/RTO.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

The script disables soft delete, stops protection with **Delete backup data**, then deletes the resource group. If deletion fails with "vault cannot be deleted as there are existing resources", check **Vault > Backup items** for soft-deleted items, undelete them (`az backup protection undelete`), then run `cleanup.ps1` again.

## My notes

_How long did the first backup take? What restore options did the portal offer?_
