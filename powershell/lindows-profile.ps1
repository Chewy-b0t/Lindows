$ErrorView = 'ConciseView'
if ($PSStyle) { $PSStyle.OutputRendering = 'PlainText' }

$script:LindowsBackend = Join-Path $PSScriptRoot 'linux-tools.ps1'

foreach ($aliasName in 'ls', 'cat', 'cp', 'mv', 'rm', 'mkdir', 'pwd', 'ps') {
    Remove-Item -Path ("Alias:{0}" -f $aliasName) -Force -ErrorAction SilentlyContinue
}

function Invoke-LindowsTool {
    & $script:LindowsBackend @args
    $global:LASTEXITCODE = $LASTEXITCODE
}

function global:prompt {
    $path = $PWD.Path
    if ($path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = '~' + $path.Substring($HOME.Length)
    }
    return "$path> "
}

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ~ { Set-Location ~ }

function ls { Invoke-LindowsTool ls @args }
function l { Invoke-LindowsTool l @args }
function ll { Invoke-LindowsTool ll @args }
function la { Invoke-LindowsTool la @args }
function lt { Invoke-LindowsTool lt @args }
function pwd { Invoke-LindowsTool pwd }
function which { Invoke-LindowsTool which @args }
function cat { Invoke-LindowsTool cat @args }
function head { Invoke-LindowsTool head @args }
function tail { Invoke-LindowsTool tail @args }
function grep { Invoke-LindowsTool grep @args }
function rg {
    $ripgrep = Get-Command rg.exe -ErrorAction SilentlyContinue
    if ($ripgrep) {
        & $ripgrep.Source @args
        return
    }
    Invoke-LindowsTool grep @args
}
function find { Invoke-LindowsTool find @args }
function cp { Invoke-LindowsTool cp @args }
function mv { Invoke-LindowsTool mv @args }
function rm { Invoke-LindowsTool rm @args }
function mkdir { Invoke-LindowsTool mkdir @args }
function touch { Invoke-LindowsTool touch @args }
function tree { Invoke-LindowsTool tree @args }
function realpath { Invoke-LindowsTool realpath @args }
function dirname { Invoke-LindowsTool dirname @args }
function basename { Invoke-LindowsTool basename @args }
function file { Invoke-LindowsTool file @args }
function env { Invoke-LindowsTool env @args }
function du { Invoke-LindowsTool du @args }
function ps { Invoke-LindowsTool ps @args }
function df { Invoke-LindowsTool df }
function date { Invoke-LindowsTool date }
function uname { Invoke-LindowsTool uname @args }
function whoami { Invoke-LindowsTool whoami }
function ln { Invoke-LindowsTool ln @args }
function chmod { Invoke-LindowsTool chmod @args }
function diff { Invoke-LindowsTool diff @args }
function tee { Invoke-LindowsTool tee @args }
function readlink { Invoke-LindowsTool readlink @args }
function free { Invoke-LindowsTool free }

function mkcd {
    param([Parameter(Mandatory = $true)][string]$Path)
    mkdir $Path
    Set-Location $Path
}

function export {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Assignments)
    foreach ($assignment in $Assignments) {
        if ($assignment -match '^(?<Name>[A-Za-z_][A-Za-z0-9_]*)=(?<Value>.*)$') {
            Set-Item -Path ("Env:{0}" -f $matches.Name) -Value $matches.Value
        }
    }
}

Set-Alias clear Clear-Host -Option AllScope
