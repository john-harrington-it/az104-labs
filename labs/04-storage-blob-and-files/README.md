# Lab 04: Storage account, blobs, SAS, lifecycle, and Azure Files

| | |
|---|---|
| Exam domain | Implement and manage storage (15-20%) |
| Scope | Resource group |
| Estimated cost | Under $0.05 for a few hours (a few MB of Standard LRS data) |
| Time | 60-90 minutes |

## Objective

- Deploy a hardened StorageV2 account: TLS 1.2, HTTPS only, **no anonymous blob access**.
- Turn on blob versioning and soft delete, and add a **lifecycle policy** (Hot > Cool > Archive > delete).
- Create a private container and use **SAS tokens** (user delegation SAS and a service SAS bound to a **stored access policy**).
- Create an **Azure Files** share and compare it with the Windows file servers and DFSR you have run.
- Optionally lock the storage firewall to your public IP.

## Exam skills covered

- Create and configure storage accounts; configure redundancy and encryption
- Configure Azure Storage firewalls and virtual networks
- Create and use SAS tokens; configure stored access policies; manage access keys
- Create and configure a container in Blob Storage; configure storage tiers
- Configure soft delete, versioning, and blob lifecycle management
- Create and configure a file share in Azure Files; snapshots and soft delete for Azure Files
- Manage data by using Azure Storage Explorer and AzCopy

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: secure account + one private container. TODOs for redundancy, firewall, data protection, lifecycle, Files. |
| `main.bicepparam` | Gives you Storage Blob Data Contributor (via `AZ104_PRINCIPAL_ID`, set by deploy.ps1) |
| `solution/` | Reference solution |
| `deploy.ps1` / `cleanup.ps1` | Deploy / delete the resource group |

## Steps

1. Complete the TODOs in `main.bicep`.
2. Deploy:

   ```powershell
   cd labs/04-storage-blob-and-files
   ./deploy.ps1 -WhatIf
   ./deploy.ps1            # add -SkipDataRole if you do not want the data-plane role
   $sa = az storage account list -g rg-az104-lab04-storage --query "[0].name" -o tsv
   ```

3. **Entra ID (RBAC) access to blobs.** Role assignments can take a few minutes to apply.

   ```powershell
   "hello from lab 04" | Out-File hello.txt
   az storage blob upload --account-name $sa -c private-docs -n hello.txt -f hello.txt --auth-mode login
   az storage blob list --account-name $sa -c private-docs --auth-mode login -o table
   ```

4. **Anonymous access is blocked.** This should return an error (`PublicAccessNotPermitted` or `ResourceNotFound`):

   ```powershell
   curl.exe -s "https://$sa.blob.core.windows.net/private-docs/hello.txt"
   ```

5. **User delegation SAS** (signed with your Entra ID credentials, max 7 days):

   ```powershell
   $expiry = (Get-Date).ToUniversalTime().AddHours(1).ToString('yyyy-MM-ddTHH:mmZ')
   $url = az storage blob generate-sas --account-name $sa -c private-docs -n hello.txt --permissions r --expiry $expiry --auth-mode login --as-user --full-uri -o tsv
   curl.exe -s $url
   ```

6. **Stored access policy + service SAS** (signed with the account key; revoke by deleting the policy):

   ```powershell
   $key = az storage account keys list -g rg-az104-lab04-storage -n $sa --query "[0].value" -o tsv
   az storage container policy create --account-name $sa --account-key $key -c private-docs -n read-1h --permissions r --expiry $expiry
   $sas = az storage blob generate-sas --account-name $sa --account-key $key -c private-docs -n hello.txt --policy-name read-1h -o tsv
   curl.exe -s "https://$sa.blob.core.windows.net/private-docs/hello.txt?$sas"
   az storage container policy delete --account-name $sa --account-key $key -c private-docs -n read-1h
   curl.exe -s "https://$sa.blob.core.windows.net/private-docs/hello.txt?$sas"   # now fails: revoked
   ```

7. **Rotate a key** (and think about what breaks when you do):

   ```powershell
   az storage account keys renew -g rg-az104-lab04-storage -n $sa --key key2
   ```

8. **Tiers and soft delete**:

   ```powershell
   az storage blob set-tier --account-name $sa -c private-docs -n hello.txt --tier Cool --auth-mode login
   az storage blob delete --account-name $sa -c private-docs -n hello.txt --auth-mode login
   az storage blob list --account-name $sa -c private-docs --include d --auth-mode login -o table
   az storage blob undelete --account-name $sa -c private-docs -n hello.txt --auth-mode login
   ```

9. **Azure Files**:

   ```powershell
   az storage file upload --account-name $sa --account-key $key --share-name departments --source hello.txt
   az storage share snapshot --account-name $sa --account-key $key --name departments
   az storage file list --account-name $sa --account-key $key --share-name departments -o table
   ```

   Mounting over SMB needs outbound TCP 445, which many home ISPs block. If `Test-NetConnection "$sa.file.core.windows.net" -Port 445` fails, use the upload commands above or Storage Explorer instead.

10. **Optional**: AzCopy and Storage Explorer. Copy a folder up with `azcopy login` then `azcopy copy ./somefolder "https://$sa.blob.core.windows.net/logs/" --recursive`, and browse the account in Azure Storage Explorer.

11. **Optional firewall**: set `allowedIpAddresses` in `solution/main.bicepparam` to your IP (`curl.exe https://ifconfig.me`), deploy with `-Solution`, and confirm access from elsewhere (for example Cloud Shell) is denied.

## Verify

```powershell
az storage account show -n $sa --query "{sku:sku.name, tls:minimumTlsVersion, httpsOnly:enableHttpsTrafficOnly, publicBlob:allowBlobPublicAccess, network:networkRuleSet.defaultAction}" -o jsonc
az storage account blob-service-properties show --account-name $sa --query "{versioning:isVersioningEnabled, softDelete:deleteRetentionPolicy}" -o jsonc
az storage account management-policy show --account-name $sa -g rg-az104-lab04-storage -o jsonc
az storage share-rm show --storage-account $sa --name departments --query "{quota:shareQuota, tier:accessTier}" -o jsonc
```

PowerShell (Az module):

```powershell
Get-AzStorageAccount -ResourceGroupName rg-az104-lab04-storage | Select-Object StorageAccountName, Sku, MinimumTlsVersion, AllowBlobPublicAccess
Get-AzStorageAccountManagementPolicy -ResourceGroupName rg-az104-lab04-storage -StorageAccountName $sa
```

## Interview talking points

- **Azure Files vs. your file servers**: Azure Files is a managed SMB share. **Azure File Sync** keeps a cached copy on a Windows Server in the branch (cloud tiering), which covers a lot of what DFSR and branch file servers were used for. Identity-based access works with on-prem **AD DS** or **Entra Kerberos**, so NTFS-style permissions carry over.
- **Redundancy**: LRS (3 copies, one datacenter), ZRS (3 zones), GRS/GZRS (plus a secondary region). Archive is not supported on ZRS/GZRS.
- **Access options, most to least preferred**: Entra ID + RBAC, user delegation SAS, service SAS with a stored access policy (revocable), account keys (full control; rotate them).
- **Lifecycle management** replaces the scheduled scripts you might have written to move old files to cheaper storage.
- **Data protection layers**: soft delete, versioning, snapshots, and (for compliance) immutability policies.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
Remove-Item hello.txt -ErrorAction SilentlyContinue
```

## My notes

_Which access method would you pick for a third-party vendor that needs one file for one day? Why?_
