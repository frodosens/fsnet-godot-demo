#!/usr/bin/env pwsh
# Headless regression gate for the Amber Bridge project (Windows / PowerShell 7).
#
# Mirrors the headless portion of tools/test.sh: the python asset checks that run
# before the GDScript loop, then its default tests (-Extended adds matrices). The full bash
# script additionally runs hundreds of multi-process network permutations; those
# need a working fsnet loopback stack and are opt-in here (-IncludeNetwork).
#
# Usage:
#   pwsh tools/test-headless.ps1 -Godot 'G:\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe'
#   pwsh tools/test-headless.ps1 -Godot $env:GODOT -Python 'C:\...\python.exe' -Filter 'test_bridge*'
#   pwsh tools/test-headless.ps1 -Godot $env:GODOT -IncludeNetwork
#
# Exit code: 0 only when every selected check passes.

[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT,
    [string]$Python = $env:AMBER_PYTHON,
    [string]$Filter = '*',
    [switch]$Extended,
    [switch]$IncludeNetwork,
    [switch]$SkipImport,
    [switch]$KeepLogs,
    [int]$TimeoutSec = 300,
    [string]$Out = 'artifacts/test-headless.csv'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$logRoot = Join-Path $repo 'artifacts/test-logs'
$csvPath = Join-Path $repo $Out

# Godot writes user data (logs, shader cache) under %APPDATA%; keep it out of the
# real profile and out of the repository so a sandboxed or read-only profile
# cannot break the run.
$testHome = Join-Path ([System.IO.Path]::GetTempPath()) 'amber-test-home'
$tmpDir = Join-Path $repo 'artifacts/tmp'
New-Item -ItemType Directory -Force -Path $testHome, $tmpDir, $logRoot, (Split-Path -Parent $csvPath) | Out-Null
# Without .gdignore the engine imports the reports and fixtures left under
# artifacts/ as project resources on the next run.
New-Item -ItemType File -Force -Path (Join-Path $repo 'artifacts/.gdignore') | Out-Null
$env:APPDATA = $testHome
$env:LOCALAPPDATA = $testHome
# Some checks build throw-away fixtures in the system temp directory; keep them in
# the repository so a restricted temp directory cannot fail the run.
$env:TMP = $tmpDir
$env:TEMP = $tmpDir
$env:TMPDIR = $tmpDir
# Python asset checks read UTF-8 sources and write UTF-8 reports; the default
# Windows locale (GBK here) would otherwise raise UnicodeDecodeError.
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'

# Lines the engine emits on every Windows run and that are not test failures.
$benign = @(
    'Failed to read the root certificate store',
    'at: get_system_ca_certificates',
    'VSync is not supported',
    # Godot 4.6.3 prints renderer-shutdown diagnostics for the dummy backend used
    # by --headless; they are not assertions and never fail a test body.
    'were leaked at exit',
    'PagedAllocator'
)
$failurePattern = 'SCRIPT ERROR|\bERROR:|\bFAIL(?:URE)?(?:\s|:)|Assertion failed|\bfailures\s*=\s*[1-9]\d*'

function Quote-Arguments([string[]]$items) {
    # Windows PowerShell 5.1 has no ProcessStartInfo.ArgumentList; quote by hand.
    ($items | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
}

function Resolve-Executable([string]$candidate, [string]$name) {    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return (Resolve-Path -LiteralPath $candidate).Path }
    foreach ($guess in @($name, "$name.exe")) {
        $cmd = Get-Command $guess -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    throw "Cannot find $name. Pass -$name explicitly."
}

function Test-Output([string]$text) {
    $kept = foreach ($line in ($text -split "`r?`n")) {
        $ignored = $false
        foreach ($b in $benign) { if ($line -like "*$b*") { $ignored = $true; break } }
        if (-not $ignored -and $line -match $failurePattern) { $line }
    }
    return @($kept)
}

function Invoke-Checked {
    param(
        [string]$Stage,
        [string]$Name,
        [string]$FileName,
        [string[]]$Arguments,
        [hashtable]$Environment = @{}
    )
    $safe = ($Name -replace '[^A-Za-z0-9_.-]', '_')
    $log = Join-Path $logRoot ("{0}.log" -f $safe)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $saved = @{}
    foreach ($k in $Environment.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
        [Environment]::SetEnvironmentVariable($k, $Environment[$k], 'Process')
    }
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new($FileName)
        $psi.Arguments = (Quote-Arguments $Arguments)
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $repo
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
            try { $proc.Kill() } catch { }
            $exit = -9
            $note = "TIMEOUT after ${TimeoutSec}s"
        } else {
            $exit = $proc.ExitCode
            $note = ''
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Set-Content -LiteralPath $log -Value ($stdout + "`n" + $stderr) -NoNewline
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k], 'Process') }
    }
    $sw.Stop()
    $text = Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue
    $errors = Test-Output $text
    $ok = ($exit -eq 0) -and ($note -eq '') -and ($errors.Count -eq 0)
    $summary = (($text -split "`r?`n") | Where-Object { $_ -match 'checks=|failures=|_OK' } | Select-Object -Last 1)
    if (-not $summary) { $summary = ($text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1) }
    $summary = ("$note " + "$summary").Trim()
    if (-not $KeepLogs -and $ok) { Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue }
    [pscustomobject]@{
        stage   = $Stage
        name    = $Name
        exit    = $exit
        seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        ok      = $ok
        summary = $summary
        log     = if ($ok -and -not $KeepLogs) { '' } else { $log }
        errors  = ($errors | Select-Object -First 3) -join ' | '
    }
}

$godotExe = Resolve-Executable $Godot 'godot'
if (-not $Python) {
    $py = Get-Command python3, python -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $py) { throw 'Cannot find python3/python. Pass -Python explicitly.' }
    $Python = $py.Source
}
$pythonExe = (Resolve-Path -LiteralPath $Python).Path

Write-Host "godot : $godotExe"
Write-Host "python: $pythonExe"
Write-Host "repo  : $repo"
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $godotExe --version 2>&1 | Out-Host
$versionExit = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
if ($versionExit -ne 0) { throw 'Godot did not report a version.' }

# The native extension is only registered after one import pass, and many assets
# have no committed .import metadata (the project relies on the importer to
# generate it), so a fresh import is part of the default run.
$extensionList = Join-Path $repo '.godot/extension_list.cfg'
if (-not $SkipImport) {
    Write-Host 'importing project ...'
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $godotExe --headless --path $repo --import *> (Join-Path $logRoot 'import.log')
    $importExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($importExit -ne 0) { throw "Project import failed; see $logRoot/import.log" }
} elseif (-not (Test-Path -LiteralPath $extensionList)) {
    throw "No .godot/extension_list.cfg; run without -SkipImport first."
}

$script = Get-Content -LiteralPath (Join-Path $repo 'tools/test.sh') -Raw
$rows = [System.Collections.Generic.List[object]]::new()

# 1. Python checks that tools/test.sh runs before the GDScript loop.
$loopMatch = [regex]::Match($script, 'for test in(?<list>[\s\S]*?);\s*do')
$preLoop = if ($loopMatch.Success) { $script.Substring(0, $loopMatch.Index) } else { $script }
$pythonChecks = [regex]::Matches($preLoop, 'run_checked python3 "\$root/(tests/[^"]+\.py)"') |
    ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$pythonChecks += [regex]::Matches($preLoop, '^python3 "\$root/(tests/[^"]+\.py)"', 'Multiline') |
    ForEach-Object { $_.Groups[1].Value }
$pythonChecks = $pythonChecks | Select-Object -Unique

foreach ($check in $pythonChecks) {
    $rows.Add((Invoke-Checked -Stage 'python' -Name $check -FileName $pythonExe `
                -Arguments @((Join-Path $repo $check)) -Environment @{ GODOT = $godotExe }))
}

# 2. Every GDScript test named in the tools/test.sh loop.
if (-not $loopMatch.Success) { throw 'Cannot find the "for test in ... do" list in tools/test.sh' }
$tests = ($loopMatch.Groups['list'].Value -split '\s+') | Where-Object { $_ -match '^test_' }
$extendedTests = Get-Content -LiteralPath (Join-Path $repo 'tools/test-extended.txt') |
    Where-Object { $_ -match '^test_' }
if (-not $Extended) { $tests = $tests | Where-Object { $_ -notin $extendedTests } }
Write-Host ("running {0} python checks and {1} godot tests (filter: {2})" -f $pythonChecks.Count, $tests.Count, $Filter)

foreach ($test in $tests) {
    if ($test -notlike $Filter) { continue }
    $rows.Add((Invoke-Checked -Stage 'godot' -Name $test -FileName $godotExe `
                -Arguments @('--headless', '--path', $repo, '--script', "res://tests/$test.gd")))
}

# Preserve separate-process preference verification in the headless gate too.
if ('test_latest_map_policy' -like $Filter) {
    $rows.Add((Invoke-Checked -Stage 'godot' -Name 'test_latest_map_policy_restart' -FileName $godotExe `
                -Arguments @('--headless', '--path', $repo, '--script', 'res://tests/test_latest_map_policy.gd') `
                -Environment @{ LATEST_MAP_RESTART = '1' }))
}
if ('test_neri_default_restart' -like $Filter) {
    foreach ($phase in @('upgrade', 'manual_off', 'relaunch')) {
        $rows.Add((Invoke-Checked -Stage 'godot' -Name "test_neri_default_restart_$phase" -FileName $godotExe `
                    -Arguments @('--headless', '--path', $repo, '--script', 'res://tests/test_neri_default_restart.gd') `
                    -Environment @{ NERI_MIGRATION_PHASE = $phase }))
    }
}

# 3. Opt-in network smoke (currently red on some Windows hosts; see docs/BASELINE.md).
if ($IncludeNetwork) {
    $rows.Add((Invoke-Checked -Stage 'network' -Name 'run_network.py' -FileName $pythonExe `
                -Arguments @((Join-Path $repo 'tests/run_network.py')) -Environment @{ GODOT = $godotExe }))
}

# Godot's importer rewrites tracked .import metadata when the engine minor version
# differs from the one the project was imported with. Restore those tracked files,
# but keep the metadata the importer generated for the ~900 assets that have no
# committed .import: deleting it leaves the project unable to load its textures
# until the next editor open ("No loader found for resource: ...").
if (Test-Path -LiteralPath (Join-Path $repo '.git')) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    git -C $repo checkout -- ':(glob)**/*.import' 2>$null
    $ErrorActionPreference = $previous
    $global:LASTEXITCODE = 0
}

$failed = @($rows | Where-Object { -not $_.ok })
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8

Write-Host ''
$rows | Sort-Object stage, name | Format-Table -AutoSize stage, name, exit, seconds, ok
$totalSeconds = [math]::Round((($rows | Measure-Object -Property seconds -Sum).Sum), 1)
Write-Host ("RESULT {0}/{1} passed in {2}s  (report: {3})" -f ($rows.Count - $failed.Count), $rows.Count, $totalSeconds, $csvPath)
foreach ($f in $failed) {
    Write-Host ''
    Write-Host ("FAILED [{0}] {1} exit={2} {3}" -f $f.stage, $f.name, $f.exit, $f.summary)
    if ($f.errors) { Write-Host ("  {0}" -f $f.errors) }
    if ($f.log) { Write-Host ("  log: {0}" -f $f.log) }
}
if ($failed.Count) { exit 1 }
exit 0
