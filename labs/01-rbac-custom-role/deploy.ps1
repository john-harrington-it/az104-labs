#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys AZ-104 lab 01: Custom RBAC role and role assignments.
.DESCRIPTION
    1. Checks that Azure CLI is installed and signed in, and shows the target subscription.
    2. Runs az deployment sub what-if so you can review every change.
    3. Asks for confirmation, then runs az deployment sub create.

    By default it deploys YOUR starter (main.bicep + main.bicepparam in this folder).
    Use -Solution to deploy the reference solution in ./solution instead.
    Use -WhatIf to preview without changing anything. Deployment scope: subscription.
.EXAMPLE
    ./deploy.ps1 -WhatIf
.EXAMPLE
    ./deploy.ps1
.EXAMPLE
    ./deploy.ps1 -Solution
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # Region for the lab resource group (and the deployment record).
    [string]$Location = 'southcentralus',

    # Entra ID group that receives the roles. Created in the README steps.
    [string]$GroupName = 'AZ104-Lab-Operators',

    # Object ID to assign instead of looking up -GroupName.
    [string]$PrincipalId,

    # Deploy the reference solution instead of your starter main.bicep.
    [switch]$Solution
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

# The .bicepparam file reads these environment variables. Remember their current values
# so they can be restored afterwards (secrets never outlive this run).
$labEnvNames = @('AZ104_PRINCIPAL_ID')
$savedEnv = @{}
foreach ($name in $labEnvNames) {
    $savedEnv[$name] = [System.Environment]::GetEnvironmentVariable($name)
}

try {
    $account = Assert-AzLabPrerequisite
    $files = Get-AzLabTemplate -LabPath $PSScriptRoot -Solution:$Solution

    if (-not $PrincipalId) {
        Write-Information "Looking up Entra ID group '$GroupName'..."
        $group = Invoke-AzLabCli -Arguments @('ad', 'group', 'show', '--group', $GroupName, '--query', 'id') -AsJson -AllowFailure
        if (-not $group) {
            throw "Group '$GroupName' not found. Create it first (README step 1) or pass -PrincipalId."
        }
        $PrincipalId = [string]$group
    }
    Write-Information "Principal    : $PrincipalId"
    $env:AZ104_PRINCIPAL_ID = $PrincipalId

    $deployArgs = @('--location', $Location, '--template-file', $files.Template, '--parameters', $files.Parameters)

    Write-Information '--- what-if (preview only; nothing changes) ---'
    Invoke-AzLabCli -Arguments (@('deployment', 'sub', 'what-if') + $deployArgs) | Out-Host

    $result = $null
    if ($PSCmdlet.ShouldProcess("subscription $($account.name)", 'Deploy lab 01 ({0})' -f $files.Kind)) {
        $deploymentName = 'az104-lab01-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        $result = Invoke-AzLabCli -Arguments (@('deployment', 'sub', 'create', '--name', $deploymentName) + $deployArgs) -AsJson
        Write-Information 'Deployment outputs:'
        $result.properties.outputs | ConvertTo-Json -Depth 5 | Out-Host
        Write-Information 'Next: work through the Verify section in README.md. When you are done: ./cleanup.ps1'
    }
}
finally {
    foreach ($name in $labEnvNames) {
        [System.Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
    }
}
