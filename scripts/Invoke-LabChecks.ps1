#Requires -Version 7.0
<#
.SYNOPSIS
    Offline checks for the whole repo: Bicep build + lint, parameter files, repo layout, and PSScriptAnalyzer.
.DESCRIPTION
    Runs the same checks locally and in GitHub Actions. Nothing here signs in to Azure
    or deploys anything.

      1. Repo layout  : every lab has its README, starter, solution, parameters, deploy and cleanup scripts.
      2. Bicep build  : every .bicep file compiles (starters, solutions, shared modules).
      3. Bicep lint   : zero linter warnings or errors, using the rules in bicepconfig.json.
      4. Parameters   : every .bicepparam file compiles against its template.
      5. PowerShell   : zero PSScriptAnalyzer findings, using PSScriptAnalyzerSettings.psd1.

    Uses the standalone bicep CLI if it is on PATH, otherwise az bicep.
.PARAMETER Root
    Repo root. Defaults to the parent of the scripts folder.
.PARAMETER SkipBicep
    Skip the Bicep steps for a quick PowerShell-only run.
.EXAMPLE
    ./scripts/Invoke-LabChecks.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Path $PSScriptRoot -Parent),

    # Skip the Bicep build/lint/parameter steps (quick PowerShell-only run).
    [switch]$SkipBicep
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
Set-StrictMode -Version Latest

$failures = [System.Collections.Generic.List[string]]::new()
$counts = [ordered]@{ Labs = 0; BicepFiles = 0; ParamFiles = 0; ScriptFiles = 0 }

function Invoke-BicepTool {
    <#
    .SYNOPSIS
        Runs a bicep subcommand with the standalone CLI or az bicep and returns exit code and output.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][ValidateSet('build', 'lint', 'build-params')][string]$Command,
        [Parameter(Mandatory)][string]$Path
    )

    $toolArgs = [System.Collections.Generic.List[string]]::new()
    $useStandalone = [bool](Get-Command -Name bicep -ErrorAction SilentlyContinue)
    if ($useStandalone) {
        $toolArgs.AddRange([string[]]@($Command, $Path))
    }
    else {
        $toolArgs.AddRange([string[]]@('bicep', $Command, '--file', $Path))
    }
    if ($Command -ne 'lint') {
        $toolArgs.Add('--stdout')
    }

    if ($useStandalone) {
        $output = & bicep @toolArgs 2>&1
    }
    else {
        $output = & az @toolArgs 2>&1
    }
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = @($output | ForEach-Object { "$_" })
    }
}

function Get-Diagnostic {
    <#
    .SYNOPSIS
        Returns only the Warning/Error diagnostic lines from bicep output.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string[]]$Line)

    $Line | Where-Object { $_ -match '\) : (Warning|Error) ' }
}

# --- 1. Repo layout -----------------------------------------------------------
Write-Information '== Repo layout'
$required = @('README.md', 'main.bicep', 'main.bicepparam', 'deploy.ps1', 'cleanup.ps1', 'solution/main.bicep', 'solution/main.bicepparam')
$readmeSections = @('## Objective', '## Exam skills covered', '## Steps', '## Verify', '## Interview talking points', '## Cleanup')
$labs = Get-ChildItem -Path (Join-Path $Root 'labs') -Directory | Sort-Object Name
foreach ($lab in $labs) {
    $counts.Labs++
    foreach ($file in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $lab.FullName $file))) {
            $failures.Add("layout: $($lab.Name) is missing $file")
        }
    }
    $starter = Join-Path $lab.FullName 'main.bicep'
    if ((Test-Path -LiteralPath $starter) -and -not (Select-String -LiteralPath $starter -Pattern '// TODO' -SimpleMatch -Quiet)) {
        $failures.Add("layout: $($lab.Name)/main.bicep has no // TODO markers (the starter should leave work to do)")
    }
    $readme = Join-Path $lab.FullName 'README.md'
    if (Test-Path -LiteralPath $readme) {
        $text = Get-Content -LiteralPath $readme -Raw
        foreach ($section in $readmeSections) {
            if (-not $text.Contains($section)) {
                $failures.Add("layout: $($lab.Name)/README.md is missing the '$section' section")
            }
        }
    }
    foreach ($script in @('deploy.ps1', 'cleanup.ps1')) {
        $path = Join-Path $lab.FullName $script
        if ((Test-Path -LiteralPath $path) -and -not (Select-String -LiteralPath $path -Pattern 'SupportsShouldProcess' -SimpleMatch -Quiet)) {
            $failures.Add("layout: $($lab.Name)/$script must support -WhatIf/-Confirm (SupportsShouldProcess)")
        }
    }
}
Write-Information ("   {0} labs checked" -f $counts.Labs)

# --- 2 and 3. Bicep build and lint ---------------------------------------------
Write-Information '== Bicep build + lint'
$bicepFiles = @()
if (-not $SkipBicep) {
    $bicepFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.bicep' -File | Sort-Object FullName
}
foreach ($file in $bicepFiles) {
    $counts.BicepFiles++
    $relative = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
    foreach ($command in @('build', 'lint')) {
        $result = Invoke-BicepTool -Command $command -Path $file.FullName
        $diagnostics = @(Get-Diagnostic -Line $result.Output)
        if ($result.ExitCode -ne 0 -or $diagnostics.Count -gt 0) {
            $failures.Add("bicep ${command}: $relative")
            $diagnostics | ForEach-Object { $failures.Add("    $_") }
            if ($diagnostics.Count -eq 0) {
                $result.Output | Select-Object -First 5 | ForEach-Object { $failures.Add("    $_") }
            }
        }
    }
    Write-Information "   ok  $relative"
}

# --- 4. Parameter files --------------------------------------------------------
Write-Information '== Bicep parameter files'
$paramFiles = @()
if (-not $SkipBicep) {
    $paramFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.bicepparam' -File | Sort-Object FullName
}
foreach ($file in $paramFiles) {
    $counts.ParamFiles++
    $relative = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
    $result = Invoke-BicepTool -Command 'build-params' -Path $file.FullName
    $diagnostics = @(Get-Diagnostic -Line $result.Output)
    if ($result.ExitCode -ne 0 -or $diagnostics.Count -gt 0) {
        $failures.Add("bicep build-params: $relative")
        $diagnostics | ForEach-Object { $failures.Add("    $_") }
    }
    Write-Information "   ok  $relative"
}

# --- 5. PSScriptAnalyzer -------------------------------------------------------
Write-Information '== PSScriptAnalyzer'
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw 'PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
}
$settings = Join-Path $Root 'PSScriptAnalyzerSettings.psd1'
$scripts = Get-ChildItem -Path $Root -Recurse -Include '*.ps1', '*.psm1', '*.psd1' -File
$counts.ScriptFiles = @($scripts).Count
$findings = @($scripts | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings $settings })
foreach ($finding in $findings) {
    $relative = [System.IO.Path]::GetRelativePath($Root, $finding.ScriptPath)
    $failures.Add(("psscriptanalyzer: {0}:{1} {2} {3}" -f $relative, $finding.Line, $finding.RuleName, $finding.Message))
}
Write-Information ("   {0} PowerShell files, {1} findings" -f $counts.ScriptFiles, $findings.Count)

# --- Summary -------------------------------------------------------------------
Write-Information ''
Write-Information ("Checked {0} labs, {1} Bicep files, {2} parameter files, {3} PowerShell files." -f $counts.Labs, $counts.BicepFiles, $counts.ParamFiles, $counts.ScriptFiles)
if ($failures.Count -gt 0) {
    Write-Information ''
    Write-Information ("FAILED with {0} problem line(s):" -f $failures.Count)
    $failures | ForEach-Object { Write-Information $_ }
    exit 1
}
Write-Information 'All checks passed.'
