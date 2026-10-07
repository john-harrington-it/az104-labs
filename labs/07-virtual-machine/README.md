# Lab 07: Virtual machine with managed disks, an extension, and auto-shutdown

| | |
|---|---|
| Exam domain | Deploy and manage Azure compute resources (20-25%) |
| Scope | Resource group |
| Estimated cost | About $0.01-0.02 per hour for a B1s Linux VM plus a few cents of disk; may be $0 on a free account's B1s hours. Windows on B2ats_v2 costs a bit more. |
| Time | 60-90 minutes |

## Objective

- Deploy a **Trusted Launch** VM (Ubuntu 24.04 by default; Windows Server 2022 in the solution) with **no public IP**.
- Attach a separate **managed data disk** and see disk caching and delete options.
- Use a **Custom Script extension** to install a web server, and manage the VM with **Run Command** instead of opening SSH/RDP to the internet.
- Configure **auto-shutdown** so a forgotten VM does not run all month.
- Practice resize, stop/deallocate, and (optionally) encryption at host.

## Exam skills covered

- Create a virtual machine
- Manage virtual machine sizes
- Manage virtual machine disks
- Configure encryption at host for Azure virtual machines
- Move a virtual machine to another resource group (stretch)
- Interpret and modify a Bicep file

## Files

| File | What it is |
|---|---|
| `main.bicep` | Starter: Linux VM + VNet/NSG/NIC + OS disk. TODOs for data disk, extension, auto-shutdown. |
| `main.bicepparam` | Reads your SSH public key from `AZ104_ADMIN_SECRET` (deploy.ps1 sets it) |
| `solution/` | Reference solution, with a Linux/Windows switch and optional encryption at host |
| `deploy.ps1` / `cleanup.ps1` | Deploy / delete the resource group |

## Steps

1. Make sure you have an SSH key pair (`ssh-keygen -t ed25519`). Only the public key is used.
2. Check the size is available in your region and what it costs:

   ```powershell
   az vm list-skus --location southcentralus --size Standard_B1s --query "[].{name:name, restrictions:restrictions}" -o jsonc
   ```

3. Complete the TODOs in `main.bicep`.
4. Deploy:

   ```powershell
   cd labs/07-virtual-machine
   ./deploy.ps1 -WhatIf
   ./deploy.ps1
   # Windows variant of the solution (prompts for a password):
   # ./deploy.ps1 -Solution -OsType Windows
   ```

5. Format the data disk from inside the VM with Run Command (Linux):

   ```powershell
   az vm run-command invoke -g rg-az104-lab07-vm -n vm-lab07 --command-id RunShellScript --scripts "lsblk; sudo parted /dev/sdc --script mklabel gpt mkpart primary ext4 0% 100%; sleep 2; sudo mkfs.ext4 -q /dev/sdc1; sudo mkdir -p /data; sudo mount /dev/sdc1 /data; df -h /data"
   ```

   Check the device name in the `lsblk` output first; it is usually `sdc` on Azure but not guaranteed.

6. Resize, then stop and deallocate:

   ```powershell
   az vm list-vm-resize-options -g rg-az104-lab07-vm -n vm-lab07 -o table
   az vm resize -g rg-az104-lab07-vm -n vm-lab07 --size Standard_B1ms
   az vm deallocate -g rg-az104-lab07-vm -n vm-lab07     # stops compute billing; "Stop" inside the OS does not
   az vm start -g rg-az104-lab07-vm -n vm-lab07
   ```

7. Stretch: encryption at host. Register the feature once (`az feature register --namespace Microsoft.Compute --name EncryptionAtHost`, then `az provider register -n Microsoft.Compute`), set `encryptionAtHost = true` in the solution parameters, and redeploy with `-Solution` (the VM must be deallocated to change it).

## Verify

```powershell
az vm show -g rg-az104-lab07-vm -n vm-lab07 --query "{size:hardwareProfile.vmSize, security:securityProfile.securityType, osDisk:storageProfile.osDisk.managedDisk.storageAccountType, dataDisks:storageProfile.dataDisks[].{lun:lun, name:name}}" -o jsonc
az vm get-instance-view -g rg-az104-lab07-vm -n vm-lab07 --query "instanceView.statuses[].displayStatus" -o tsv
az vm extension list -g rg-az104-lab07-vm --vm-name vm-lab07 --query "[].{name:name, state:provisioningState}" -o table
az vm run-command invoke -g rg-az104-lab07-vm -n vm-lab07 --command-id RunShellScript --scripts "curl -s localhost" --query "value[0].message" -o tsv
az resource show -g rg-az104-lab07-vm -n shutdown-computevm-vm-lab07 --resource-type Microsoft.DevTestLab/schedules --query "properties.{time:dailyRecurrence.time, tz:timeZoneId, status:status}"
```

PowerShell (Az module):

```powershell
Get-AzVM -ResourceGroupName rg-az104-lab07-vm -Name vm-lab07 -Status
Invoke-AzVMRunCommand -ResourceGroupName rg-az104-lab07-vm -VMName vm-lab07 -CommandId RunShellScript -ScriptString 'curl -s localhost'
```

## Interview talking points

- **VMware to Azure mapping** from your vCenter background: VM size = CPU/RAM reservation picked from a menu; managed disk = VMDK on a datastore with an SLA; availability sets/zones = host and rack/site anti-affinity (DRS rules); Trusted Launch = Secure Boot + vTPM; the Azure VM agent and extensions = VMware Tools plus a config-management hook.
- **Stopped vs. deallocated**: shutting down inside the OS keeps the compute reservation and still bills; deallocate releases it.
- **No public IP by design**: Run Command, Azure Bastion, or a VPN instead of exposing 22/3389. Bastion is the exam answer for browser-based RDP/SSH (it bills hourly, so it is not deployed here).
- **Disk choices**: Standard HDD, Standard SSD, Premium SSD (v2), Ultra; host caching ReadWrite for OS disks, None/ReadOnly for data disks depending on the workload.
- **Extensions vs. images**: Custom Script for small post-deploy steps; a golden image (Azure Compute Gallery) for anything big, similar to your Citrix golden image process.
- **Default outbound access is going away** for new VNets; this lab opts back in to install packages, and production would use NAT Gateway.

## Cleanup

```powershell
./cleanup.ps1 -WhatIf
./cleanup.ps1
```

The OS disk and NIC are set to delete with the VM, but the data disk is set to **Detach**. Deleting the resource group removes it anyway; deleting only the VM would leave it behind (and billing).

## My notes

_What is the hourly price of the size you used in your region? What did auto-shutdown email you?_
