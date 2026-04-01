$ErrorActionPreference = 'Stop'
if ($PSStyle) { $PSStyle.OutputRendering = 'PlainText' }

if ($args.Count -eq 0) {
    throw 'usage: linux-tools <command> [args...]'
}

$Command = [string]$args[0]
$ArgsList = if ($args.Count -gt 1) { [string[]]$args[1..($args.Count - 1)] } else { @() }

function ConvertTo-LongListing {
    param([Parameter(ValueFromPipeline = $true)]$Item)
    process {
        $size = if ($Item.PSIsContainer) { '<DIR>' } else { [string]$Item.Length }
        '{0,-5} {1,-16} {2,10} {3}' -f $Item.Mode, $Item.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $size, $Item.Name
    }
}

function ConvertTo-GrepLine {
    param([Parameter(ValueFromPipeline = $true)]$Match)
    process {
        $path = if ($Match.Path) { $Match.Path } else { '<stdin>' }
        '{0}:{1}:{2}' -f $path, $Match.LineNumber, $Match.Line.TrimEnd()
    }
}

function Get-ListingSpec {
    param([string[]]$Values)

    $showAll = $false
    $limit = 50
    $paths = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $Values.Count; $i++) {
        $value = $Values[$i]
        switch ($value) {
            '--all' { $showAll = $true; continue }
            '-n' {
                if ($i + 1 -lt $Values.Count) {
                    $i++
                    $limit = [int]$Values[$i]
                }
                continue
            }
            default { $paths.Add($value) }
        }
    }

    if ($paths.Count -eq 0) { $paths.Add('.') }

    [pscustomobject]@{
        ShowAll = $showAll
        Limit   = $limit
        Paths   = @($paths)
    }
}

function Get-FindSpec {
    param([string[]]$Values)

    $searchPath = '.'
    $name = '*'
    $type = $null
    $showAll = $false
    $limit = 50

    for ($i = 0; $i -lt $Values.Count; $i++) {
        switch ($Values[$i]) {
            '--all' { $showAll = $true }
            '-n' {
                if ($i + 1 -lt $Values.Count) {
                    $i++
                    $limit = [int]$Values[$i]
                }
            }
            '-name' {
                if ($i + 1 -lt $Values.Count) {
                    $i++
                    $name = $Values[$i]
                }
            }
            '-type' {
                if ($i + 1 -lt $Values.Count) {
                    $i++
                    $type = $Values[$i]
                }
            }
            default {
                if (-not $Values[$i].StartsWith('-')) {
                    $searchPath = $Values[$i]
                }
            }
        }
    }

    [pscustomobject]@{
        SearchPath = $searchPath
        Name       = $name
        Type       = $type
        ShowAll    = $showAll
        Limit      = $limit
    }
}

function Get-PathsOrCurrent {
    param([string[]]$Paths)
    if (-not $Paths -or $Paths.Count -eq 0) { return @('.') }
    return $Paths
}

function Get-HeadTailSpec {
    param([string[]]$Values)
    $count = 20
    $paths = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $Values.Count; $i++) {
        $value = $Values[$i]
        if ($value -eq '-n' -and $i + 1 -lt $Values.Count) {
            $i++
            $count = [int]$Values[$i]
            continue
        }

        if ($value -match '^\d+$' -and $paths.Count -eq 0) {
            $count = [int]$value
            continue
        }

        $paths.Add($value)
    }

    [pscustomobject]@{
        Count = $count
        Paths = @($paths)
    }
}

function Get-CopyMoveSpec {
    param([string[]]$Values)
    $force = $false
    $recurse = $false
    $paths = New-Object System.Collections.Generic.List[string]

    foreach ($value in $Values) {
        switch ($value) {
            '--' { continue }
            '-f' { $force = $true; continue }
            '--force' { $force = $true; continue }
            '-r' { $recurse = $true; continue }
            '-R' { $recurse = $true; continue }
            '-rf' { $force = $true; $recurse = $true; continue }
            '-fr' { $force = $true; $recurse = $true; continue }
            default { $paths.Add($value) }
        }
    }

    [pscustomobject]@{
        Force = $force
        Recurse = $recurse
        Paths = @($paths)
    }
}

function Get-RemoveSpec {
    param([string[]]$Values)
    $force = $false
    $recurse = $false
    $paths = New-Object System.Collections.Generic.List[string]

    foreach ($value in $Values) {
        switch ($value) {
            '--' { continue }
            '-f' { $force = $true; continue }
            '--force' { $force = $true; continue }
            '-r' { $recurse = $true; continue }
            '-R' { $recurse = $true; continue }
            '-rf' { $force = $true; $recurse = $true; continue }
            '-fr' { $force = $true; $recurse = $true; continue }
            default { $paths.Add($value) }
        }
    }

    [pscustomobject]@{
        Force = $force
        Recurse = $recurse
        Paths = @($paths)
    }
}

function Get-CopyMovePlan {
    param(
        [string[]]$Values,
        [string]$Verb
    )

    $spec = Get-CopyMoveSpec $Values
    if ($spec.Paths.Count -lt 2) { throw "usage: $Verb <source...> <destination>" }

    $destination = $spec.Paths[-1]
    $sources = if ($spec.Paths.Count -gt 2) { $spec.Paths[0..($spec.Paths.Count - 2)] } else { @($spec.Paths[0]) }

    if ($sources.Count -gt 1) {
        $destItem = Get-Item -LiteralPath $destination -ErrorAction SilentlyContinue
        if (-not $destItem -or -not $destItem.PSIsContainer) {
            throw "${Verb}: destination must be an existing directory when using multiple sources"
        }
    }

    [pscustomobject]@{
        Force       = $spec.Force
        Recurse     = $spec.Recurse
        Sources     = $sources
        Destination = $destination
    }
}

function Get-ResolvedTargetPath {
    param(
        [string]$Source,
        [string]$Destination
    )

    $destItem = Get-Item -LiteralPath $Destination -ErrorAction SilentlyContinue
    if ($destItem -and $destItem.PSIsContainer) {
        return Join-Path -Path $Destination -ChildPath (Split-Path -Path $Source -Leaf)
    }

    return $Destination
}

switch ($Command.ToLowerInvariant()) {
    'ls' {
        $paths = Get-PathsOrCurrent $ArgsList
        Get-ChildItem -Path $paths -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = 'PSIsContainer'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            Select-Object -ExpandProperty Name
    }
    'l' {
        $paths = Get-PathsOrCurrent $ArgsList
        Get-ChildItem -Path $paths -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = 'PSIsContainer'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            Select-Object -ExpandProperty Name
    }
    'll' {
        $spec = Get-ListingSpec $ArgsList
        $lines = @(Get-ChildItem -Path $spec.Paths -Force -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = 'PSIsContainer'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            ConvertTo-LongListing)
        if (-not $spec.ShowAll) { $lines = $lines | Select-Object -First $spec.Limit }
        $lines
    }
    'la' {
        $paths = Get-PathsOrCurrent $ArgsList
        Get-ChildItem -Path $paths -Force -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = 'PSIsContainer'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            Select-Object -ExpandProperty Name
    }
    'lt' {
        $spec = Get-ListingSpec $ArgsList
        $lines = @(Get-ChildItem -Path $spec.Paths -Force -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = 'LastWriteTime'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            ConvertTo-LongListing)
        if (-not $spec.ShowAll) { $lines = $lines | Select-Object -First $spec.Limit }
        $lines
    }
    'pwd' { (Get-Location).Path }
    'which' {
        foreach ($name in $ArgsList) {
            $cmd = Get-Command -Name $name -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) {
                if ($cmd.Path) { $cmd.Path; continue }
                if ($cmd.Source) { $cmd.Source; continue }
            }

            $cmd = Get-Command -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $cmd) { continue }
            if ($cmd.Path) { $cmd.Path; continue }
            if ($cmd.Source) { $cmd.Source; continue }
            if ($cmd.CommandType -eq 'Alias') { $cmd.Definition; continue }
            if ($cmd.CommandType -eq 'Function') { 'function:{0}' -f $cmd.Name; continue }
            $cmd.Name
        }
    }
    'cat' {
        foreach ($path in $ArgsList) {
            [System.IO.File]::ReadAllText((Resolve-Path -Path $path))
        }
    }
    'touch' {
        foreach ($path in $ArgsList) {
            if (Test-Path -LiteralPath $path) {
                (Get-Item -LiteralPath $path).LastWriteTime = Get-Date
            } else {
                New-Item -ItemType File -Path $path -Force | Out-Null
            }
        }
    }
    'mkdir' {
        foreach ($path in $ArgsList) {
            if ($path -eq '--' -or $path -eq '-p' -or $path -eq '--parents') { continue }
            if (Test-Path -LiteralPath $path) { continue }
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    'head' {
        $spec = Get-HeadTailSpec $ArgsList
        if ($spec.Paths.Count -gt 0) { Get-Content -Path $spec.Paths -TotalCount $spec.Count }
    }
    'tail' {
        $spec = Get-HeadTailSpec $ArgsList
        if ($spec.Paths.Count -gt 0) { Get-Content -Path $spec.Paths -Tail $spec.Count }
    }
    'grep' {
        if ($ArgsList.Count -gt 0) {
            $pattern = $ArgsList[0]
            $paths = if ($ArgsList.Count -gt 1) { $ArgsList[1..($ArgsList.Count - 1)] } else { @() }
            if ($paths.Count -gt 0) {
                Select-String -Pattern $pattern -SimpleMatch -Path $paths | ConvertTo-GrepLine
            }
        }
    }
    'find' {
        $spec = Get-FindSpec $ArgsList
        $items = Get-ChildItem -Path $spec.SearchPath -Recurse -Force -ErrorAction SilentlyContinue -Filter $spec.Name
        if ($spec.Type -eq 'f') { $items = $items | Where-Object { -not $_.PSIsContainer } }
        if ($spec.Type -eq 'd') { $items = $items | Where-Object { $_.PSIsContainer } }
        $lines = @($items | Select-Object -ExpandProperty FullName)
        if (-not $spec.ShowAll) { $lines = $lines | Select-Object -First $spec.Limit }
        $lines
    }
    'cp' {
        $plan = Get-CopyMovePlan -Values $ArgsList -Verb 'cp'
        foreach ($source in $plan.Sources) {
            $targetPath = Get-ResolvedTargetPath -Source $source -Destination $plan.Destination
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Force -Recurse -ErrorAction SilentlyContinue
            }
            Copy-Item -LiteralPath $source -Destination $plan.Destination -Force -Recurse:$plan.Recurse
        }
    }
    'mv' {
        $plan = Get-CopyMovePlan -Values $ArgsList -Verb 'mv'
        foreach ($source in $plan.Sources) {
            $targetPath = Get-ResolvedTargetPath -Source $source -Destination $plan.Destination
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Force -Recurse -ErrorAction SilentlyContinue
            }
            Move-Item -LiteralPath $source -Destination $plan.Destination -Force
        }
    }
    'rm' {
        $spec = Get-RemoveSpec $ArgsList
        $errorAction = if ($spec.Force) { 'SilentlyContinue' } else { 'Stop' }
        foreach ($path in $spec.Paths) {
            if ($path.IndexOfAny([char[]]'*?[') -ge 0) {
                Remove-Item -Path $path -Force:$spec.Force -Recurse:$spec.Recurse -ErrorAction $errorAction
            } else {
                Remove-Item -LiteralPath $path -Force:$spec.Force -Recurse:$spec.Recurse -ErrorAction $errorAction
            }
        }
    }
    'realpath' {
        if ($ArgsList.Count -gt 0) {
            Resolve-Path -Path $ArgsList | Select-Object -ExpandProperty Path
        }
    }
    'dirname' {
        foreach ($path in $ArgsList) {
            $parent = Split-Path -Path $path -Parent
            if ([string]::IsNullOrWhiteSpace($parent)) { '.' } else { $parent }
        }
    }
    'basename' {
        foreach ($path in $ArgsList) {
            Split-Path -Path $path -Leaf
        }
    }
    'file' {
        foreach ($item in Get-Item -Path $ArgsList -ErrorAction SilentlyContinue) {
            if ($item.PSIsContainer) {
                '{0}: directory' -f $item.FullName
            } elseif ($item.Extension -match '^\.(exe|dll)$') {
                '{0}: PE executable' -f $item.FullName
            } elseif ($item.Extension -match '^\.(cmd|bat|ps1|sh)$') {
                '{0}: script' -f $item.FullName
            } elseif ($item.Extension -match '^\.(txt|md|json|yaml|yml|toml|xml|csv)$') {
                '{0}: text' -f $item.FullName
            } else {
                '{0}: data ({1})' -f $item.FullName, $item.Extension
            }
        }
    }
    'env' {
        if ($ArgsList -contains '--all') {
            Get-ChildItem Env: |
                Sort-Object Name |
                ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }
            break
        }

        foreach ($name in 'USERPROFILE', 'HOME', 'USERNAME', 'COMPUTERNAME', 'ComSpec', 'SHELL', 'TERM', 'TEMP', 'TMP', 'APPDATA', 'LOCALAPPDATA') {
            if (Test-Path ("Env:{0}" -f $name)) {
                '{0}={1}' -f $name, (Get-Item ("Env:{0}" -f $name)).Value
            }
        }

        if (Test-Path Env:PATH) {
            'PATH_ENTRIES={0}' -f (($env:PATH -split ';').Where({ $_ -ne '' }).Count)
        }

        if (Test-Path Env:PSModulePath) {
            'PSMODULEPATH_ENTRIES={0}' -f (($env:PSModulePath -split ';').Where({ $_ -ne '' }).Count)
        }

        'PWD={0}' -f (Get-Location).Path
    }
    'du' {
        $path = if ($ArgsList.Count -gt 0) { $ArgsList[0] } else { '.' }
        $size = (Get-ChildItem -Path $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        '{0} {1}' -f ([math]::Round(($size / 1MB), 2)), (Resolve-Path -Path $path -ErrorAction SilentlyContinue).Path
    }
    'ps' {
        $showAll = $ArgsList -contains '--all'
        $limit = 20
        for ($i = 0; $i -lt $ArgsList.Count; $i++) {
            if ($ArgsList[$i] -eq '-n' -and $i + 1 -lt $ArgsList.Count) {
                $i++
                $limit = [int]$ArgsList[$i]
            }
        }

        $lines = @(Get-Process |
            Sort-Object ProcessName |
            ForEach-Object {
                '{0,6} {1,-28} {2,8} {3,8}' -f $_.Id, $_.ProcessName, ([math]::Round($_.CPU, 1)), ([math]::Round($_.WorkingSet64 / 1MB, 1))
            })
        if (-not $showAll) { $lines = $lines | Select-Object -First $limit }
        $lines
    }
    'df' {
        Get-PSDrive -PSProvider FileSystem |
            ForEach-Object {
                '{0,-5} {1,10} {2,10} {3}' -f $_.Name, ([math]::Round(($_.Used / 1GB), 2)), ([math]::Round(($_.Free / 1GB), 2)), $_.Root
            }
    }
    'date' { Get-Date -Format 'ddd MMM dd HH:mm:ss yyyy' }
    'uname' {
        $showAll = $ArgsList -contains '-a'
        $os = Get-CimInstance Win32_OperatingSystem
        if ($showAll) {
            '{0} {1} {2} {3}' -f $env:COMPUTERNAME, $os.Caption, $os.Version, $os.OSArchitecture
        } else {
            'Windows'
        }
    }
    'whoami' { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
    'tree' {
        $path = if ($ArgsList.Count -gt 0) { $ArgsList[0] } else { '.' }
        if (Get-Command tree.com -ErrorAction SilentlyContinue) {
            & tree.com $path /F
            break
        }

        $root = Resolve-Path -Path $path -ErrorAction SilentlyContinue
        if (-not $root) { break }

        $root.Path
        Get-ChildItem -Path $root.Path -Recurse -Force -ErrorAction SilentlyContinue |
            Sort-Object FullName |
            ForEach-Object {
                $relative = $_.FullName.Substring($root.Path.Length).TrimStart('\')
                $depth = ($relative -split '\\').Count - 1
                ('  ' * $depth) + $_.Name
            }
    }
    'ln' {
        $symbolic = $false
        $values = New-Object System.Collections.Generic.List[string]
        foreach ($value in $ArgsList) {
            if ($value -eq '-s') {
                $symbolic = $true
                continue
            }
            $values.Add($value)
        }
        if ($values.Count -lt 2) { throw 'usage: ln [-s] <target> <link>' }
        $itemType = if ($symbolic) { 'SymbolicLink' } else { 'HardLink' }
        New-Item -ItemType $itemType -Path $values[1] -Target $values[0] -Force | Out-Null
    }
    'chmod' {
        if ($ArgsList.Count -lt 2) { throw 'usage: chmod <mode> <path>' }
        $mode = $ArgsList[0]
        $path = $ArgsList[1]
        switch -Regex ($mode) {
            '^\+w$' { (Get-Item -Path $path).IsReadOnly = $false; break }
            '^-w$' { (Get-Item -Path $path).IsReadOnly = $true; break }
            '^[0-7]{3,4}$' {
                $writeEnabled = [int]$mode.Substring($mode.Length - 1, 1) -ge 2
                (Get-Item -Path $path).IsReadOnly = -not $writeEnabled
                break
            }
            '^\+x$' { break }
            '^-x$' { break }
            default { Write-Warning 'chmod on Windows only maps simple write-bit changes to the read-only flag.' }
        }
    }
    'diff' {
        if ($ArgsList.Count -lt 2) { throw 'usage: diff <left> <right>' }
        Compare-Object (Get-Content -Path $ArgsList[0]) (Get-Content -Path $ArgsList[1])
    }
    'tee' {
        if ($ArgsList.Count -lt 1) { throw 'usage: tee <path>' }
        $input | Tee-Object -FilePath $ArgsList[0]
    }
    'readlink' {
        if ($ArgsList.Count -lt 1) { throw 'usage: readlink <path>' }
        (Get-Item -Path $ArgsList[0] -ErrorAction SilentlyContinue).Target
    }
    'free' {
        $os = Get-CimInstance Win32_OperatingSystem
        'free_mb={0} total_mb={1}' -f ([math]::Round($os.FreePhysicalMemory / 1KB, 2)), ([math]::Round($os.TotalVisibleMemorySize / 1KB, 2))
    }
    default { throw "unknown linux-tools command: $Command" }
}
