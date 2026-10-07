#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys AZ-104 lab 00: Subscription budget with email alerts.
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
    # Email address for budget alerts. Falls back to the AZ104_ALERT_EMAIL environment variable.
    [string]$AlertEmail = $env:AZ104_ALERT_EMAIL,

    # Region where Azure stores the deployment record (budgets themselves are not regional).
    [string]$Location = 'southcentralus',

    # Deploy the reference solution instead of your starter main.bicep.
    [switch]$Solution
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

# The .bicepparam file reads these environment variables. Remember their current values
# so they can be restored afterwards (secrets never outlive this run).
$labEnvNames = @('AZ104_ALERT_EMAIL')
$savedEnv = @{}
foreach ($name in $labEnvNames) {
    $savedEnv[$name] = [System.Environment]::GetEnvironmentVariable($name)
}

try {
    $account = Assert-AzLabPrerequisite
    $files = Get-AzLabTemplate -LabPath $PSScriptRoot -Solution:$Solution

    if ([string]::IsNullOrWhiteSpace($AlertEmail) -or $AlertEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$' -or $AlertEmail -like '*@example.com') {
        throw 'Pass a real email address with -AlertEmail (or set $env:AZ104_ALERT_EMAIL). It is never written to the repo.'
    }
    $env:AZ104_ALERT_EMAIL = $AlertEmail

    $deployArgs = @('--location', $Location, '--template-file', $files.Template, '--parameters', $files.Parameters)

    Write-Information '--- what-if (preview only; nothing changes) ---'
    Invoke-AzLabCli -Arguments (@('deployment', 'sub', 'what-if') + $deployArgs) | Out-Host

    $result = $null
    if ($PSCmdlet.ShouldProcess("subscription $($account.name)", 'Deploy lab 00 ({0})' -f $files.Kind)) {
        $deploymentName = 'az104-lab00-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
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
