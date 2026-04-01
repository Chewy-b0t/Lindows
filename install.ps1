[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Lindows'),
    [switch]$SkipPowerShellProfile,
    [switch]$SkipCmdAutoRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$markerStart = '# >>> Lindows >>>'
$markerEnd = '# <<< Lindows <<<'

$commandWrappers = @(
    'ls', 'l', 'll', 'la', 'lt',
    'pwd', 'which', 'cat', 'touch', 'head', 'tail',
    'grep', 'find', 'cp', 'mv', 'rm', 'mkdir',
    'realpath', 'dirname', 'basename', 'file',
    'env', 'du', 'ps', 'df', 'date', 'uname', 'whoami',
    'tree', 'ln', 'chmod', 'diff', 'tee', 'readlink', 'free'
)

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-ProfileSnippet {
    param([Parameter(Mandatory = $true)][string]$ProfilePath)

    Ensure-Directory -Path (Split-Path -Parent $ProfilePath)

    $snippet = @(
        $markerStart,
        ('$lindowsProfile = ''{0}''' -f (Join-Path $InstallRoot 'powershell\lindows-profile.ps1')),
        'if (Test-Path -LiteralPath $lindowsProfile) {',
        '    . $lindowsProfile',
        '}',
        $markerEnd
    ) -join [Environment]::NewLine

    $existing = if (Test-Path -LiteralPath $ProfilePath) {
        Get-Content -LiteralPath $ProfilePath -Raw
    } else {
        ''
    }

    if ($existing -match [regex]::Escape($markerStart)) {
        $pattern = [regex]::Escape($markerStart) + '.*?' + [regex]::Escape($markerEnd)
        $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $snippet }, 'Singleline')
        Set-Content -LiteralPath $ProfilePath -Value $updated
        return
    }

    if ($existing -and -not $existing.EndsWith([Environment]::NewLine)) {
        $existing += [Environment]::NewLine
    }

    Set-Content -LiteralPath $ProfilePath -Value ($existing + $snippet + [Environment]::NewLine)
}

function Set-CmdAutoRun {
    $cmdInit = Join-Path $InstallRoot 'cmd\cmd-init.cmd'
    $keyPath = 'HKCU:\Software\Microsoft\Command Processor'
    if (-not (Test-Path -LiteralPath $keyPath)) {
        New-Item -Path $keyPath -Force | Out-Null
    }

    $existing = (Get-ItemProperty -Path $keyPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    $call = ('if exist "{0}" call "{0}"' -f $cmdInit)

    if ([string]::IsNullOrWhiteSpace($existing)) {
        $newValue = $call
    } elseif ($existing -like "*$cmdInit*") {
        $newValue = $existing
    } else {
        $newValue = "$existing & $call"
    }

    Set-ItemProperty -Path $keyPath -Name AutoRun -Value $newValue
}

Ensure-Directory -Path $InstallRoot
Ensure-Directory -Path (Join-Path $InstallRoot 'cmd')
Ensure-Directory -Path (Join-Path $InstallRoot 'bin')
Ensure-Directory -Path (Join-Path $InstallRoot 'powershell')

Copy-Item -LiteralPath (Join-Path $repoRoot 'cmd\cmd-init.cmd') -Destination (Join-Path $InstallRoot 'cmd\cmd-init.cmd') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'cmd\macros.doskey') -Destination (Join-Path $InstallRoot 'cmd\macros.doskey') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'powershell\linux-tools.ps1') -Destination (Join-Path $InstallRoot 'powershell\linux-tools.ps1') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'powershell\lindows-profile.ps1') -Destination (Join-Path $InstallRoot 'powershell\lindows-profile.ps1') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'Start Lindows CMD.bat') -Destination (Join-Path $InstallRoot 'Start Lindows CMD.bat') -Force

foreach ($command in $commandWrappers) {
    $wrapperPath = Join-Path $InstallRoot ("bin\{0}.cmd" -f $command)
    $wrapper = @(
        '@echo off',
        ('pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\powershell\linux-tools.ps1" {0} %*' -f $command)
    ) -join [Environment]::NewLine
    Set-Content -LiteralPath $wrapperPath -Value ($wrapper + [Environment]::NewLine)
}

$specialWrappers = @{
    'mkcd.cmd'  = @('@echo off', 'if "%~1"=="" exit /b 1', 'mkdir "%~1" 2>nul', 'cd /d "%~1"')
    'up.cmd'    = @('@echo off', 'cd ..')
    'home.cmd'  = @('@echo off', 'cd /d "%USERPROFILE%"')
    'clear.cmd' = @('@echo off', 'cls')
}

foreach ($name in $specialWrappers.Keys) {
    $content = ($specialWrappers[$name] -join [Environment]::NewLine) + [Environment]::NewLine
    Set-Content -LiteralPath (Join-Path $InstallRoot ("bin\{0}" -f $name)) -Value $content
}

if (-not $SkipPowerShellProfile) {
    Set-ProfileSnippet -ProfilePath $PROFILE.CurrentUserAllHosts
}

if (-not $SkipCmdAutoRun) {
    Set-CmdAutoRun
}

Write-Host ('Installed Lindows to {0}' -f $InstallRoot)
if (-not $SkipPowerShellProfile) {
    Write-Host ('Updated PowerShell profile: {0}' -f $PROFILE.CurrentUserAllHosts)
}
if (-not $SkipCmdAutoRun) {
    Write-Host 'Updated cmd.exe AutoRun.'
}
Write-Host 'Open a new shell to use it.'
