# AZ-104 Labs: hands-on Azure Administrator study repo

[![CI](https://github.com/john-harrington-it/az104-labs/actions/workflows/ci.yml/badge.svg)](https://github.com/john-harrington-it/az104-labs/actions/workflows/ci.yml)
![Bicep](https://img.shields.io/badge/IaC-Bicep-0078D4?logo=microsoftazure&logoColor=white)
![PowerShell 7](https://img.shields.io/badge/PowerShell-7.x-5391FE?logo=powershell&logoColor=white)
![Status: in progress](https://img.shields.io/badge/status-in%20progress-orange)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

> **This is my personal study and lab repo for the Microsoft AZ-104 (Azure Administrator) exam. It is a work in progress, not production work.** The progress table below shows which labs I have actually completed.

I'm a Systems Engineer with 15+ years of on-prem and hybrid Microsoft infrastructure: Active Directory, Entra ID hybrid identity, MFA and Conditional Access, Exchange hybrid, VMware, Citrix, and Veeam. I have not run Azure IaaS in production yet. These labs are how I'm building that hands-on skill: each one deploys real resources with Bicep, verifies them with Azure CLI and PowerShell, and tears them down again.

**Why this matters:** most of the AZ-104 blueprint maps onto work I've done on-prem, like AD delegation (RBAC), Group Policy (Azure Policy), file servers and DFSR (Azure Files), VMware clusters (VMs, disks, scale sets), and Veeam (Azure Backup). Doing it hands-on in Azure turns that background into hybrid-cloud skills I can show, not just describe.

The lab guides, starter templates, and reference solutions were put together as a study kit with AI assistance. The learning is in completing the `// TODO:` gaps myself, deploying, breaking things, and writing up what I found in each lab's notes.

## Progress

Status key: ⬜ not started · 🟨 in progress · ✅ completed (starter finished, deployed, verified, cleaned up)

Domains and weights are from the [official AZ-104 study guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104) (skills measured as of April 17, 2026).

| Status | Lab | Exam domain | Main skills | Rough cost* |
|:---:|---|---|---|---|
| ⬜ | [00 Setup and budget alert](labs/00-setup-and-budget) | Identities and governance (20-25%) | Tooling, budgets, cost alerts | $0 |
| ⬜ | [01 Custom RBAC role](labs/01-rbac-custom-role) | Identities and governance (20-25%) | Entra groups, custom role, scoped assignments | $0 |
| ⬜ | [02 Policy and locks](labs/02-policy-and-locks) | Identities and governance (20-25%) | Allowed locations, required/inherited tags, locks | $0 |
| ⬜ | [03 Management groups and tags](labs/03-management-groups-and-tags) | Identities and governance (20-25%) | Management groups (CLI), tag merge | $0 |
| ⬜ | [04 Storage, blobs, and Azure Files](labs/04-storage-blob-and-files) | Storage (15-20%) | SAS, stored access policy, lifecycle, soft delete, Files | < $0.05 |
| ⬜ | [05 VNet, NSGs, and ASGs](labs/05-vnet-nsg-asg) | Virtual networking (15-20%) | Subnets, NSG rules, ASGs, service endpoints | $0 |
| ⬜ | [06 Peering and UDRs](labs/06-peering-and-udr) | Virtual networking (15-20%) | Hub-and-spoke peering, route tables | $0 |
| ⬜ | [07 Virtual machine](labs/07-virtual-machine) | Compute (20-25%) | Trusted Launch VM, data disk, extension, auto-shutdown | ~$0.02/hr |
| ⬜ | [08 App Service](labs/08-app-service) | Compute (20-25%) | Plan, web app, TLS, managed identity, slots | $0 (S1 step ~$0.10/hr) |
| ⬜ | [09 VM scale set + load balancer](labs/09-vmss-load-balancer) | Networking + Compute | Standard LB, probes, outbound rules, VMSS, autoscale | ~$0.05/hr |
| ⬜ | [10 Azure Monitor and alerts](labs/10-monitoring-and-alerts) | Monitor and maintain (10-15%) | Log Analytics, diagnostic settings, alerts, KQL | a few cents |
| ⬜ | [11 Backup and Recovery Services vault](labs/11-backup-recovery-vault) | Monitor and maintain (10-15%) | Vault, enhanced policy, backup and restore | < $1 same day |

\*Rough estimates for US regions, pay-as-you-go, with the lab cleaned up the same session. Prices change and vary by region; check the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) before you deploy anything that bills by the hour.

## How each lab works

```text
labs/NN-name/
├── README.md          objective, exam skills, steps, verify commands, interview talking points, cleanup
├── main.bicep         STARTER: deploys something valid, with // TODO: gaps to complete
├── main.bicepparam    parameters for the starter
├── deploy.ps1         sign-in check -> what-if -> confirm -> deploy (supports -WhatIf / -Confirm)
├── cleanup.ps1        lists what will be deleted -> confirm -> deletes the lab's resource group
└── solution/
    ├── main.bicep     reference solution (look after trying)
    └── main.bicepparam
```

The loop for every lab:

1. Read the lab README and finish the `// TODO:` items in `main.bicep`. VS Code with the Bicep extension shows errors and property hints as you type.
2. `./deploy.ps1 -WhatIf` to preview, then `./deploy.ps1`. It always runs `az deployment ... what-if` and asks before deploying.
3. Work through the **Verify** commands, then answer the **Interview talking points** out loud.
4. `./cleanup.ps1`. Then mark the lab ✅ above and fill in **My notes**.

Stuck? `./deploy.ps1 -Solution` deploys the reference solution, and `git diff --no-index main.bicep solution/main.bicep` shows what's left.

## Prerequisites

| Tool | Why |
|---|---|
| Azure subscription: [free account](https://azure.microsoft.com/free/) or pay-as-you-go **with a budget alert** (lab 00) | Somewhere to deploy. Use a personal study subscription, never an employer's. |
| [Azure CLI](https://aka.ms/installazurecli) 2.60+ | Deployments and verification (`az login`) |
| Bicep CLI (`az bicep install`) | Compiles `.bicep` files |
| [VS Code](https://code.visualstudio.com/) + Bicep extension | Editing with IntelliSense and the linter (`.vscode/extensions.json` recommends it) |
| [PowerShell 7](https://aka.ms/powershell) | Runs `deploy.ps1` / `cleanup.ps1` on Windows, macOS, or Linux |
| An SSH key pair (`ssh-keygen -t ed25519`) | Linux VMs in labs 07, 09, 11 (only the public key is used) |
| Az PowerShell module (optional) | Alternative verify commands in each lab |

## Cost safety

These labs are designed to cost little or nothing, but Azure bills by the hour for some resources. The guardrails:

- **Lab 00 comes first.** It creates a monthly budget with alerts at 50% and 80% of actual spend and 100% of forecast.
- **Every lab lives in its own resource group** (`rg-az104-labNN-*`), and every `cleanup.ps1` deletes that resource group. Run it at the end of each session.
- **Cheapest SKUs by default**: B1s VMs, Standard_LRS disks and storage, F1 (Free) App Service, a capped Log Analytics workspace (0.1 GB/day), LRS backup storage.
- **Nothing expensive is left running.** Azure Firewall, Bastion, VPN/ExpressRoute gateways, and Application Gateway are covered as talking points, not deployed. If you try one on your own, delete it within the hour.
- **Auto-shutdown** is on for the lab 07 VM (7 PM Central).
- **Everything is tagged** `project=az104-labs`. Find leftovers any time:

  ```powershell
  az group list --tag project=az104-labs --output table
  ```

- Free-account credits and free-tier hours change; check what your offer includes in **Cost Management** before deploying VMs.

## Repo checks (CI)

GitHub Actions runs [`scripts/Invoke-LabChecks.ps1`](scripts/Invoke-LabChecks.ps1) on every push. It needs **no Azure credentials and never deploys anything**:

- `bicep build` and `bicep lint` on every `.bicep` file (starters, solutions, shared modules), failing on any warning or error, with the rules in [`bicepconfig.json`](bicepconfig.json)
- `bicep build-params` on every `.bicepparam` file
- Repo layout checks (each lab has its README sections, starter TODOs, solution, and `-WhatIf`-capable scripts)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) with zero findings ([settings](PSScriptAnalyzerSettings.psd1))

Run the same checks locally:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser   # once
./scripts/Invoke-LabChecks.ps1
```

API versions were current when the labs were written (October 2026). The `use-recent-api-versions` linter rule is set to `info` so CI doesn't start failing as versions age. Run `bicep lint` now and then and treat its suggestions as a maintenance exercise.

## Layout

```text
.
├── labs/                 one folder per lab (00-11)
├── modules/              shared Bicep modules (small Linux VM used by lab 11)
├── scripts/
│   ├── AzLab.psm1        helpers used by every deploy.ps1 / cleanup.ps1
│   └── Invoke-LabChecks.ps1
├── bicepconfig.json      linter rules
└── PSScriptAnalyzerSettings.psd1
```

## License

[MIT](LICENSE)
