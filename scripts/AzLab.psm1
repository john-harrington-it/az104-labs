#Requires -Version 7.0
<#
    Shared helpers for the lab deploy.ps1 and cleanup.ps1 scripts.

    These helpers only read state or run the exact Azure CLI command they are given.
    Every decision that changes something (create, deploy, delete) stays in the lab
    script itself, behind $PSCmdlet.ShouldProcess, so -WhatIf and -Confirm work there.
#>

Set-StrictMode -Version Latest

function Invoke-AzLabCli {
    <#
    .SYNOPSIS
        Runs an Azure CLI command and throws if it fails.
    .DESCRIPTION
        Passes the arguments to az unchanged. With -AsJson the command runs with
        --output json and the result is converted to objects. Otherwise the CLI output
        is returned as text (what-if output, tables, and so on).
    .PARAMETER Arguments
        The az arguments, for example: group, show, --name, rg-az104-lab04.
    .PARAMETER AsJson
        Return parsed JSON instead of text.
    .PARAMETER AllowFailure
        Return $null instead of throwing when az exits with a non-zero code.
    .EXAMPLE
        Invoke-AzLabCli -Arguments @('group', 'exists', '--name', 'rg-az104-lab04') -AsJson
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Arguments,

        [switch]$AsJson,

        [switch]$AllowFailure
    )

    $cliArgs = [System.Collections.Generic.List[string]]::new()
    $cliArgs.AddRange($Arguments)
    if ($AsJson) {
        $cliArgs.AddRange([string[]]@('--output', 'json'))
    }

    Write-Verbose ("az {0}" -f ($cliArgs -join ' '))
    $output = & az @cliArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        if ($AllowFailure) {
            return $null
        }
        throw ("Azure CLI command failed (exit code {0}): az {1}" -f $exitCode, ($Arguments -join ' '))
    }

    if ($AsJson) {
        $text = ($output | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }
        return $text | ConvertFrom-Json
    }
    return $output
}

function Assert-AzLabPrerequisite {
    <#
    .SYNOPSIS
        Checks that the Azure CLI is installed and signed in, then shows the target subscription.
    .DESCRIPTION
        Stops with a clear message if az is missing or not signed in. Returns the
        current account (subscription) object so the caller can show or use it.
    .EXAMPLE
        $account = Assert-AzLabPrerequisite
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param()

    if (-not (Get-Command -Name az -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI (az) was not found. Install it from https://aka.ms/installazurecli and run az login.'
    }

    $account = Invoke-AzLabCli -Arguments @('account', 'show') -AsJson -AllowFailure
    if ($null -eq $account) {
        throw 'You are not signed in to Azure CLI. Run: az login  (then az account set --subscription <name-or-id>)'
    }

    Write-Information ("Subscription : {0} ({1})" -f $account.name, $account.id)
    Write-Information ("Signed in as : {0}" -f $account.user.name)
    return $account
}

function Test-AzLabResourceGroup {
    <#
    .SYNOPSIS
        Returns $true if the resource group exists in the current subscription.
    .PARAMETER Name
        Resource group name.
    .EXAMPLE
        Test-AzLabResourceGroup -Name rg-az104-lab04-storage
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $result = Invoke-AzLabCli -Arguments @('group', 'exists', '--name', $Name) -AsJson
    return [bool]$result
}

function Get-AzLabTemplate {
    <#
    .SYNOPSIS
        Returns the template and parameter file paths for a lab.
    .DESCRIPTION
        By default returns your starter files (main.bicep and main.bicepparam in the lab
        folder). With -Solution returns the reference files in the solution folder.
    .PARAMETER LabPath
        The lab folder (pass $PSScriptRoot from deploy.ps1).
    .PARAMETER Solution
        Use the reference solution instead of the starter.
    .EXAMPLE
        Get-AzLabTemplate -LabPath $PSScriptRoot -Solution
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$LabPath,

        [switch]$Solution
    )

    $folder = $LabPath
    if ($Solution) {
        $folder = Join-Path -Path $LabPath -ChildPath 'solution'
    }

    $template = Join-Path -Path $folder -ChildPath 'main.bicep'
    $parameters = Join-Path -Path $folder -ChildPath 'main.bicepparam'
    foreach ($path in @($template, $parameters)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing file: $path"
        }
    }

    $kind = 'starter'
    if ($Solution) {
        $kind = 'solution'
    }
    Write-Information ("Template     : {0} ({1})" -f $template, $kind)

    return [pscustomobject]@{
        Template   = $template
        Parameters = $parameters
        Kind       = $kind
    }
}

function Get-AzLabTag {
    <#
    .SYNOPSIS
        Returns the standard lab tags as az CLI key=value strings.
    .DESCRIPTION
        Every lab resource group gets the same tags so you can find (and bill-check)
        anything left behind: az group list --tag project=az104-labs -o table
    .PARAMETER Lab
        Two-digit lab number, for example 04.
    .EXAMPLE
        Get-AzLabTag -Lab 04
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^\d{2}$')]
        [string]$Lab
    )

    return [string[]]@(
        'project=az104-labs'
        "lab=$Lab"
        'environment=study'
        'costCenter=az104-study'
        ('createdOn={0}' -f (Get-Date -Format 'yyyy-MM-dd'))
    )
}

function Get-AzLabSshPublicKey {
    <#
    .SYNOPSIS
        Finds an SSH public key to use for lab Linux VMs.
    .DESCRIPTION
        Looks for ~/.ssh/id_ed25519.pub, then ~/.ssh/id_rsa.pub, unless a path is given.
        Only the public key is read. Create a key pair with: ssh-keygen -t ed25519
    .PARAMETER Path
        Optional path to a .pub file.
    .EXAMPLE
        Get-AzLabSshPublicKey
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Path
    )

    $candidates = @()
    if ($Path) {
        $candidates += $Path
    }
    else {
        $sshFolder = Join-Path -Path $HOME -ChildPath '.ssh'
        $candidates += (Join-Path -Path $sshFolder -ChildPath 'id_ed25519.pub')
        $candidates += (Join-Path -Path $sshFolder -ChildPath 'id_rsa.pub')
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $key = (Get-Content -LiteralPath $candidate -Raw).Trim()
            if ($key -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-\S+) ') {
                throw "$candidate does not look like an SSH public key."
            }
            Write-Information "SSH key      : $candidate"
            return $key
        }
    }
    throw 'No SSH public key found. Create one with: ssh-keygen -t ed25519   (or pass -SshPublicKeyPath)'
}

function Get-AzLabSignedInUserId {
    <#
    .SYNOPSIS
        Returns the Entra ID object ID of the signed-in az CLI user.
    .DESCRIPTION
        Used by labs that grant you a data-plane role (for example Storage Blob Data
        Contributor) so you can practice with --auth-mode login instead of account keys.
    .EXAMPLE
        Get-AzLabSignedInUserId
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $id = Invoke-AzLabCli -Arguments @('ad', 'signed-in-user', 'show', '--query', 'id') -AsJson -AllowFailure
    if (-not $id) {
        throw 'Could not read your Entra ID object ID (az ad signed-in-user show). Pass it with -PrincipalId instead.'
    }
    return [string]$id
}

Export-ModuleMember -Function @(
    'Invoke-AzLabCli'
    'Assert-AzLabPrerequisite'
    'Test-AzLabResourceGroup'
    'Get-AzLabTemplate'
    'Get-AzLabTag'
    'Get-AzLabSshPublicKey'
    'Get-AzLabSignedInUserId'
)
