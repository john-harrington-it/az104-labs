#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys AZ-104 lab 07: Virtual machine with disks, extension, and auto-shutdown.
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
    [string]$ResourceGroupName = 'rg-az104-lab07-vm',

    # Azure region. Keep it in the allowed list of lab 02 if you did that lab.
    [string]$Location = 'southcentralus',

    # Linux (Ubuntu, SSH key) or Windows (Server 2022, password). Windows needs -Solution.
    [ValidateSet('Linux', 'Windows')]
    [string]$OsType = 'Linux',

    # VM size. Defaults to Standard_B1s for Linux and Standard_B2ats_v2 for Windows.
    [string]$VmSize,

    # Path to your SSH public key (.pub). Defaults to ~/.ssh/id_ed25519.pub, then ~/.ssh/id_rsa.pub.
    [string]$SshPublicKeyPath,

    # Deploy the reference solution instead of your starter main.bicep.
    [switch]$Solution
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

# The .bicepparam file reads these environment variables. Remember their current values
# so they can be restored afterwards (secrets never outlive this run).
$labEnvNames = @('AZ104_ADMIN_SECRET', 'AZ104_OS_TYPE', 'AZ104_VM_SIZE')
$savedEnv = @{}
foreach ($name in $labEnvNames) {
    $savedEnv[$name] = [System.Environment]::GetEnvironmentVariable($name)
}

try {
    $null = Assert-AzLabPrerequisite
    $files = Get-AzLabTemplate -LabPath $PSScriptRoot -Solution:$Solution

    if ($OsType -eq 'Windows' -and -not $Solution) {
        throw 'The starter template is Linux-only. Use -Solution for the Windows variant, or add Windows support to main.bicep yourself.'
    }
    if ($OsType -eq 'Linux') {
        $env:AZ104_ADMIN_SECRET = Get-AzLabSshPublicKey -Path $SshPublicKeyPath
        if (-not $VmSize) { $VmSize = 'Standard_B1s' }
    }
    else {
        $password = Read-Host -Prompt 'Windows admin password (12+ chars, upper, lower, number, symbol)' -AsSecureString
        $env:AZ104_ADMIN_SECRET = [System.Net.NetworkCredential]::new('', $password).Password
        if (-not $VmSize) { $VmSize = 'Standard_B2ats_v2' }
    }
    $env:AZ104_OS_TYPE = $OsType
    $env:AZ104_VM_SIZE = $VmSize
    Write-Information "VM           : $OsType, $VmSize"

    if (-not (Test-AzLabResourceGroup -Name $ResourceGroupName)) {
        if ($WhatIfPreference) {
            Write-Information "What if: would create resource group $ResourceGroupName in $Location, then show the deployment what-if."
            Write-Information 'Run without -WhatIf to see the full what-if. You are still asked before anything is deployed.'
            return
        }
        Write-Information "Creating empty resource group $ResourceGroupName in $Location (free)..."
        $null = Invoke-AzLabCli -Arguments (@('group', 'create', '--name', $ResourceGroupName, '--location', $Location, '--tags') + (Get-AzLabTag -Lab '07')) -AsJson
    }

    $deployArgs = @('--resource-group', $ResourceGroupName, '--template-file', $files.Template, '--parameters', $files.Parameters)

    Write-Information '--- what-if (preview only; nothing changes) ---'
    Invoke-AzLabCli -Arguments (@('deployment', 'group', 'what-if') + $deployArgs) | Out-Host

    $result = $null
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'Deploy lab 07 ({0})' -f $files.Kind)) {
        $deploymentName = 'az104-lab07-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        $result = Invoke-AzLabCli -Arguments (@('deployment', 'group', 'create', '--name', $deploymentName) + $deployArgs) -AsJson
        Write-Information 'Deployment outputs:'
        $result.properties.outputs | ConvertTo-Json -Depth 5 | Out-Host
        Write-Information 'Next: work through the Verify section in README.md. When you are done: ./cleanup.ps1'
    }
    else {
        Write-Information "Nothing deployed. If the resource group was just created it is empty (free); ./cleanup.ps1 removes it."
    }
}
finally {
    foreach ($name in $labEnvNames) {
        [System.Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
    }
}
