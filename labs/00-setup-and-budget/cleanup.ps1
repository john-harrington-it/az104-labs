#Requires -Version 7.0
<#
.SYNOPSIS
    Removes the lab 00 budget. Usually you should KEEP it.
.DESCRIPTION
    The budget is free and is your early-warning system for every other lab.
    Only run this if you are closing the subscription or replacing the budget.
    Shows the budget, asks for confirmation (or honors -WhatIf), then deletes it.
.EXAMPLE
    ./cleanup.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # Name of the budget created by this lab.
    [string]$BudgetName = 'budget-az104-labs'
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

$null = Assert-AzLabPrerequisite
$budget = Invoke-AzLabCli -Arguments @('consumption', 'budget', 'show', '--budget-name', $BudgetName) -AsJson -AllowFailure
if (-not $budget) {
    Write-Information "Budget $BudgetName not found. Nothing to delete."
    return
}

Write-Information ("Budget {0}: {1} per {2}" -f $budget.name, $budget.amount, $budget.timeGrain)
Write-Warning 'Budgets are free. Keeping this one is recommended while you work through the labs.'
if ($PSCmdlet.ShouldProcess($BudgetName, 'Delete subscription budget')) {
    $null = Invoke-AzLabCli -Arguments @('consumption', 'budget', 'delete', '--budget-name', $BudgetName)
    Write-Information "Deleted budget $BudgetName."
}
