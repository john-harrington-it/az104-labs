#Requires -Version 7.0
<#
.SYNOPSIS
    Deletes everything AZ-104 lab 01 created (Custom RBAC role and role assignments).
.DESCRIPTION
    Lists the resources in the lab resource group, then deletes the whole group after you
    confirm. Use -WhatIf to see what would be deleted without deleting anything.
    Also removes the role assignments at the resource group and the custom role definition.
.EXAMPLE
    ./cleanup.ps1 -WhatIf
.EXAMPLE
    ./cleanup.ps1
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # Resource group used by deploy.ps1.
    [string]$ResourceGroupName = 'rg-az104-lab01-rbac',

    # Return immediately instead of waiting for the delete to finish.
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

$account = Assert-AzLabPrerequisite

if (Test-AzLabResourceGroup -Name $ResourceGroupName) {
    Write-Information "Resources in ${ResourceGroupName}:"
    Invoke-AzLabCli -Arguments @('resource', 'list', '--resource-group', $ResourceGroupName, '--query', '[].{name:name, type:type}', '--output', 'table') | Out-Host

    $rgId = Invoke-AzLabCli -Arguments @('group', 'show', '--name', $ResourceGroupName, '--query', 'id') -AsJson
    $assignments = @(Invoke-AzLabCli -Arguments @('role', 'assignment', 'list', '--scope', $rgId) -AsJson | Where-Object { $_.scope -eq $rgId })
    foreach ($assignment in $assignments) {
        if ($PSCmdlet.ShouldProcess("$($assignment.roleDefinitionName) for $($assignment.principalId)", 'Remove role assignment at the lab resource group')) {
            $null = Invoke-AzLabCli -Arguments @('role', 'assignment', 'delete', '--ids', $assignment.id)
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
    Write-Information "Resource group $ResourceGroupName not found. Nothing to delete there."
}

$roleName = 'AZ-104 Lab VM Operator'
$role = @(Invoke-AzLabCli -Arguments @('role', 'definition', 'list', '--custom-role-only', 'true', '--name', $roleName) -AsJson)
if ($role.Count -gt 0) {
    if ($PSCmdlet.ShouldProcess($roleName, 'Delete custom role definition')) {
        $null = Invoke-AzLabCli -Arguments @('role', 'definition', 'delete', '--name', $roleName, '--scope', "/subscriptions/$($account.id)")
        Write-Information "Deleted custom role '$roleName'."
    }
}
Write-Information 'The Entra ID group (AZ104-Lab-Operators) and any test users are left in place. Remove them with az ad group delete / az ad user delete if you no longer need them.'

Write-Information 'Check nothing is left behind: az group list --tag project=az104-labs --output table'
