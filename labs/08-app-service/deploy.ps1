#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys AZ-104 lab 08: App Service plan and web app.
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
    [string]$ResourceGroupName = 'rg-az104-lab08-appservice',

    # Azure region. Keep it in the allowed list of lab 02 if you did that lab.
    [string]$Location = 'southcentralus',

    # Plan tier for the solution template: F1 (free), B1, or S1 (slots/autoscale, billed hourly).
    [ValidateSet('F1', 'B1', 'S1')]
    [string]$Sku = 'F1',

    # After deploying, zip ./app and push it with az webapp deploy.
    [switch]$DeployApp,

    # Deploy the reference solution instead of your starter main.bicep.
    [switch]$Solution
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../scripts/AzLab.psm1') -Force

# The .bicepparam file reads these environment variables. Remember their current values
# so they can be restored afterwards (secrets never outlive this run).
$labEnvNames = @('AZ104_APP_SKU')
$savedEnv = @{}
foreach ($name in $labEnvNames) {
    $savedEnv[$name] = [System.Environment]::GetEnvironmentVariable($name)
}

try {
    $null = Assert-AzLabPrerequisite
    $files = Get-AzLabTemplate -LabPath $PSScriptRoot -Solution:$Solution

    $env:AZ104_APP_SKU = $Sku
    if ($Solution) {
        Write-Information "Plan SKU     : $Sku"
        if ($Sku -ne 'F1') {
            Write-Warning "$Sku is billed by the hour. Scale back to F1 (./deploy.ps1 -Solution -Sku F1) or run ./cleanup.ps1 when you finish."
        }
    }

    if (-not (Test-AzLabResourceGroup -Name $ResourceGroupName)) {
        if ($WhatIfPreference) {
            Write-Information "What if: would create resource group $ResourceGroupName in $Location, then show the deployment what-if."
            Write-Information 'Run without -WhatIf to see the full what-if. You are still asked before anything is deployed.'
            return
        }
        Write-Information "Creating empty resource group $ResourceGroupName in $Location (free)..."
        $null = Invoke-AzLabCli -Arguments (@('group', 'create', '--name', $ResourceGroupName, '--location', $Location, '--tags') + (Get-AzLabTag -Lab '08')) -AsJson
    }

    $deployArgs = @('--resource-group', $ResourceGroupName, '--template-file', $files.Template, '--parameters', $files.Parameters)

    Write-Information '--- what-if (preview only; nothing changes) ---'
    Invoke-AzLabCli -Arguments (@('deployment', 'group', 'what-if') + $deployArgs) | Out-Host

    $result = $null
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'Deploy lab 08 ({0})' -f $files.Kind)) {
        $deploymentName = 'az104-lab08-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        $result = Invoke-AzLabCli -Arguments (@('deployment', 'group', 'create', '--name', $deploymentName) + $deployArgs) -AsJson
        Write-Information 'Deployment outputs:'
        $result.properties.outputs | ConvertTo-Json -Depth 5 | Out-Host
        Write-Information 'Next: work through the Verify section in README.md. When you are done: ./cleanup.ps1'
    }
    else {
        Write-Information "Nothing deployed. If the resource group was just created it is empty (free); ./cleanup.ps1 removes it."
    }

    if ($DeployApp) {
        $appName = $null
        if ($result) {
            $appName = $result.properties.outputs.webAppName.value
        }
        if (-not $appName -and -not $WhatIfPreference) {
            throw 'Could not read webAppName from the deployment outputs.'
        }
        $zip = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'az104-lab08-app.zip'
        if ($PSCmdlet.ShouldProcess($appName, 'Zip ./app and deploy it with az webapp deploy')) {
            Compress-Archive -Path (Join-Path $PSScriptRoot 'app/*') -DestinationPath $zip -Force
            $null = Invoke-AzLabCli -Arguments @('webapp', 'deploy', '--resource-group', $ResourceGroupName, '--name', $appName, '--src-path', $zip, '--type', 'zip') -AsJson
            Remove-Item -LiteralPath $zip -Force
            Write-Information "App deployed: https://$appName.azurewebsites.net"
        }
    }
}
finally {
    foreach ($name in $labEnvNames) {
        [System.Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
    }
}
