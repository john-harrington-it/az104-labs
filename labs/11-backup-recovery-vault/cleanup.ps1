#Requires -Version 7.0
<#
.SYNOPSIS
    Deletes everything AZ-104 lab 11 created (Recovery Services vault and VM backup).
.DESCRIPTION
    Lists the resources in the lab resource group, then deletes the whole group after you
    confirm. Use -WhatIf to see what would be deleted without deleting anything.
    Disables vault soft delete and stops protection with data deletion first,
    otherwise the vault (and so the resource group) cannot be deleted.
.EXAMPLE
    ./cleanup.ps1 -WhatIf
.EXAMPLE
    ./cleanup.ps1
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # Resource group used by deploy.ps1.
    [string]$ResourceGroupName = 'rg-az104-lab11-backup',

    # Return immediately instead of waiting for the delete to finish.
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

$null = Assert-AzLabPrerequisite

if (Test-AzLabResourceGroup -Name $ResourceGroupName) {
    Write-Information "Resources in ${ResourceGroupName}:"
    Invoke-AzLabCli -Arguments @('resource', 'list', '--resource-group', $ResourceGroupName, '--query', '[].{name:name, type:type}', '--output', 'table') | Out-Host

    $vaults = @(Invoke-AzLabCli -Arguments @('backup', 'vault', 'list', '--resource-group', $ResourceGroupName) -AsJson)
    foreach ($vault in $vaults) {
        if ($PSCmdlet.ShouldProcess($vault.name, 'Disable soft delete so backup data can be removed today')) {
            $null = Invoke-AzLabCli -Arguments @('backup', 'vault', 'backup-properties', 'set', '--name', $vault.name, '--resource-group', $ResourceGroupName, '--soft-delete-feature-state', 'Disable') -AsJson
        }
        $items = @(Invoke-AzLabCli -Arguments @('backup', 'item', 'list', '--vault-name', $vault.name, '--resource-group', $ResourceGroupName, '--backup-management-type', 'AzureIaasVM') -AsJson)
        foreach ($item in $items) {
            if ($PSCmdlet.ShouldProcess($item.properties.friendlyName, 'Stop protection and DELETE all backup data')) {
                $null = Invoke-AzLabCli -Arguments @('backup', 'protection', 'disable', '--vault-name', $vault.name, '--resource-group', $ResourceGroupName, '--container-name', $item.properties.containerName, '--item-name', $item.name, '--backup-management-type', 'AzureIaasVM', '--delete-backup-data', 'true', '--yes') -AsJson
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'Delete resource group and EVERYTHING in it')) {
        $deleteArgs = @('group', 'delete', '--name', $ResourceGroupName, '--yes')
        if ($NoWait) {
            $deleteArgs += '--no-wait'
        }
        $null = Invoke-AzLabCli -Arguments $deleteArgs
        Write-Information "Deleted resource group $ResourceGroupName (or started deleting it with -NoWait)."
    }
}
else {
    Write-Information "Resource group $ResourceGroupName not found. Nothing to delete."
    return
}

Write-Information 'Check nothing is left behind: az group list --tag project=az104-labs --output table'
