#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys AZ-104 lab 03: Management groups and tags.
.DESCRIPTION
    1. Checks that Azure CLI is installed and signed in, and shows the target subscription.
    2. Creates the lab resource group (tagged project=az104-labs) if it does not exist.
    3. Runs az deployment group what-if so you can review every change.
    4. Asks for confirmation, then runs az deployment group create.

    By default it deploys YOUR starter (main.bicep + main.bicepparam in this folder).
    Use -Solution to deploy the reference solution in ./solution instead.
    Use -WhatIf to preview without changing anything. Deployment scope: resource group.
.EXAMPLE
    ./deploy.ps1 -WhatIf
.EXAMPLE
    ./deploy.ps1
.EXAMPLE
    ./deploy.ps1 -Solution
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # Resource group for this lab. It is created (tagged) if it does not exist.
    [string]$ResourceGroupName = 'rg-az104-lab03-tags',

    # Azure region. Keep it in the allowed list of lab 02 if you did that lab.
    [string]$Location = 'southcentralus',

    # Also create the lab management groups with Azure CLI (mg-az104-lab > mg-az104-sandbox).
    [switch]$CreateManagementGroups,

    # Deploy the reference solution instead of your starter main.bicep.
    [switch]$Solution
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

$null = Assert-AzLabPrerequisite
$files = Get-AzLabTemplate -LabPath $PSScriptRoot -Solution:$Solution

if (-not (Test-AzLabResourceGroup -Name $ResourceGroupName)) {
    if ($WhatIfPreference) {
        Write-Information "What if: would create resource group $ResourceGroupName in $Location, then show the deployment what-if."
        Write-Information 'Run without -WhatIf to see the full what-if. You are still asked before anything is deployed.'
        return
    }
    Write-Information "Creating empty resource group $ResourceGroupName in $Location (free)..."
    $null = Invoke-AzLabCli -Arguments (@('group', 'create', '--name', $ResourceGroupName, '--location', $Location, '--tags') + (Get-AzLabTag -Lab '03')) -AsJson
}

$deployArgs = @('--resource-group', $ResourceGroupName, '--template-file', $files.Template, '--parameters', $files.Parameters)

Write-Information '--- what-if (preview only; nothing changes) ---'
Invoke-AzLabCli -Arguments (@('deployment', 'group', 'what-if') + $deployArgs) | Out-Host

$result = $null
if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'Deploy lab 03 ({0})' -f $files.Kind)) {
    $deploymentName = 'az104-lab03-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
    $result = Invoke-AzLabCli -Arguments (@('deployment', 'group', 'create', '--name', $deploymentName) + $deployArgs) -AsJson
    Write-Information 'Deployment outputs:'
    $result.properties.outputs | ConvertTo-Json -Depth 5 | Out-Host
    Write-Information 'Next: work through the Verify section in README.md. When you are done: ./cleanup.ps1'
}
else {
    Write-Information "Nothing deployed. If the resource group was just created it is empty (free); ./cleanup.ps1 removes it."
}

if ($CreateManagementGroups) {
    if ($PSCmdlet.ShouldProcess('mg-az104-lab, mg-az104-sandbox', 'Create management groups')) {
        $null = Invoke-AzLabCli -Arguments @('account', 'management-group', 'create', '--name', 'mg-az104-lab', '--display-name', 'AZ-104 Lab') -AsJson
        $null = Invoke-AzLabCli -Arguments @('account', 'management-group', 'create', '--name', 'mg-az104-sandbox', '--display-name', 'AZ-104 Lab - Sandbox', '--parent', 'mg-az104-lab') -AsJson
        Write-Information 'Management groups created. Your subscription was NOT moved; see the README for the optional move step.'
    }
}
