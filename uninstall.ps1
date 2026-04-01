[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Lindows')
)

$ErrorActionPreference = 'Stop'

$markerStart = '# >>> Lindows >>>'
$markerEnd = '# <<< Lindows <<<'

function Remove-ProfileSnippet {
    param([Parameter(Mandatory = $true)][string]$ProfilePath)

    if (-not (Test-Path -LiteralPath $ProfilePath)) {
        return
    }

    $existing = Get-Content -LiteralPath $ProfilePath -Raw
    if (-not ($existing -match [regex]::Escape($markerStart))) {
        return
    }

    $pattern = [regex]::Escape($markerStart) + '.*?' + [regex]::Escape($markerEnd) + '\r?\n?'
    $updated = [regex]::Replace($existing, $pattern, '', 'Singleline')
    Set-Content -LiteralPath $ProfilePath -Value $updated
}

function Remove-CmdAutoRun {
    param([Parameter(Mandatory = $true)][string]$CmdInitPath)

    $keyPath = 'HKCU:\Software\Microsoft\Command Processor'
    $existing = (Get-ItemProperty -Path $keyPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    if ([string]::IsNullOrWhiteSpace($existing)) {
        return
    }

    $escaped = [regex]::Escape(('if exist "{0}" call "{0}"' -f $CmdInitPath))
    $updated = [regex]::Replace($existing, "(\s*&\s*)?$escaped(\s*&\s*)?", '', 'IgnoreCase')
    $updated = [regex]::Replace($updated, '^\s*&\s*', '')
    $updated = [regex]::Replace($updated, '\s*&\s*$', '')
    $updated = $updated.Trim()

    if ([string]::IsNullOrWhiteSpace($updated)) {
        Remove-ItemProperty -Path $keyPath -Name AutoRun -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty -Path $keyPath -Name AutoRun -Value $updated
    }
}

Remove-ProfileSnippet -ProfilePath $PROFILE.CurrentUserAllHosts
Remove-CmdAutoRun -CmdInitPath (Join-Path $InstallRoot 'cmd\cmd-init.cmd')

if (Test-Path -LiteralPath $InstallRoot) {
    Remove-Item -LiteralPath $InstallRoot -Recurse -Force
}

Write-Host ('Removed Lindows from {0}' -f $InstallRoot)
