#Requires -Version 7.0
<#
.SYNOPSIS
    Deletes everything AZ-104 lab 02 created (Azure Policy and resource locks).
.DESCRIPTION
    Lists the resources in the lab resource group, then deletes the whole group after you
    confirm. Use -WhatIf to see what would be deleted without deleting anything.
    Removes the resource lock(s) and policy assignments first; a lock blocks deletion even for Owners.
.EXAMPLE
    ./cleanup.ps1 -WhatIf
.EXAMPLE
    ./cleanup.ps1
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # Resource group used by deploy.ps1.
    [string]$ResourceGroupName = 'rg-az104-lab02-governance',

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

    $locks = @(Invoke-AzLabCli -Arguments @('lock', 'list', '--resource-group', $ResourceGroupName) -AsJson)
    foreach ($lock in $locks) {
        if ($PSCmdlet.ShouldProcess($lock.name, "Remove $($lock.level) lock (locks block deletion, even for Owners)")) {
            $null = Invoke-AzLabCli -Arguments @('lock', 'delete', '--ids', $lock.id)
        }
    }
    $rgId = Invoke-AzLabCli -Arguments @('group', 'show', '--name', $ResourceGroupName, '--query', 'id') -AsJson
    $policyAssignments = @(Invoke-AzLabCli -Arguments @('policy', 'assignment', 'list', '--resource-group', $ResourceGroupName) -AsJson | Where-Object { $_.scope -eq $rgId })
    foreach ($policyAssignment in $policyAssignments) {
        if ($PSCmdlet.ShouldProcess($policyAssignment.name, 'Remove policy assignment')) {
            $null = Invoke-AzLabCli -Arguments @('policy', 'assignment', 'delete', '--name', $policyAssignment.name, '--resource-group', $ResourceGroupName)
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
