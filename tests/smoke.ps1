[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempRoot = Join-Path $env:TEMP ('lindows-smoke-' + [guid]::NewGuid().ToString('N'))
$installRoot = Join-Path $tempRoot 'install'
$workRoot = Join-Path $tempRoot 'workspace'

New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

try {
    & (Join-Path $repoRoot 'install.ps1') -InstallRoot $installRoot -SkipPowerShellProfile -SkipCmdAutoRun

    Push-Location $workRoot

    & (Join-Path $installRoot 'bin\ls.cmd') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'ls.cmd failed' }

    & (Join-Path $installRoot 'bin\mkdir.cmd') -p demo
    if (-not (Test-Path -LiteralPath (Join-Path $workRoot 'demo'))) { throw 'mkdir failed' }

    & (Join-Path $installRoot 'bin\touch.cmd') demo\alpha.txt
    if (-not (Test-Path -LiteralPath (Join-Path $workRoot 'demo\alpha.txt'))) { throw 'touch failed' }

    'hello' | Set-Content -LiteralPath (Join-Path $workRoot 'demo\alpha.txt')
    $catOutput = & (Join-Path $installRoot 'bin\cat.cmd') demo\alpha.txt
    if (($catOutput -join "`n").Trim() -ne 'hello') { throw 'cat failed' }

    & (Join-Path $installRoot 'bin\cp.cmd') demo\alpha.txt demo\beta.txt
    if (-not (Test-Path -LiteralPath (Join-Path $workRoot 'demo\beta.txt'))) { throw 'cp failed' }

    $grepOutput = & (Join-Path $installRoot 'bin\grep.cmd') hello demo\beta.txt
    if (-not (($grepOutput -join "`n") -match 'hello')) { throw 'grep failed' }

    $findOutput = & (Join-Path $installRoot 'bin\find.cmd') . -name *.txt
    if (-not (($findOutput -join "`n") -match 'alpha.txt')) { throw 'find failed' }

    & (Join-Path $installRoot 'bin\rm.cmd') demo\beta.txt
    if (Test-Path -LiteralPath (Join-Path $workRoot 'demo\beta.txt')) { throw 'rm failed' }

    Pop-Location
    Write-Host 'Smoke tests passed.'
}
finally {
    Set-Location $repoRoot
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
