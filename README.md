# Lindows

Linux-style commands for `cmd.exe` and PowerShell on Windows.

`Lindows` gives Windows shells a small, predictable command layer backed by PowerShell. It is not WSL, not Git Bash, and not a full Unix environment. It is a lightweight compatibility shim for the commands people reach for first:

- `ls`, `ll`, `la`, `lt`
- `pwd`, `which`, `cat`, `head`, `tail`
- `grep`, `find`, `realpath`, `dirname`, `basename`, `file`
- `cp`, `mv`, `rm`, `mkdir`, `touch`
- `ps`, `df`, `du`, `env`, `date`, `uname`, `whoami`
- `mkcd`, `..`, `...`, `....`

## Install

Run from PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

Default install path:

```text
%LOCALAPPDATA%\Lindows
```

The installer copies the portable scripts, generates `cmd.exe` wrappers, wires `cmd.exe` startup through `AutoRun`, adds a PowerShell profile snippet, and installs a `Start Lindows CMD.bat` launcher.

## Use

Open a new `cmd.exe` or PowerShell window after install.

```powershell
ls
ll
grep TODO README.md
find . -name *.ps1
mkdir -p demo
touch demo\file.txt
cat demo\file.txt
```

For a dedicated `cmd.exe` shell, run `Start Lindows CMD.bat`.

## What it is not

- not a Bash replacement
- not byte-for-byte GNU behavior
- not a package manager
- not a repo-specific profile

This project intentionally excludes local-machine aliases, auth helpers, model launchers, and other personal tooling.

## Safety

File commands map to Windows behavior. `rm -rf`, `cp`, and `mv` are destructive in the same way you would expect on Linux. Read the command before you run it.

## Uninstall

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\uninstall.ps1
```

## Verify

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\tests\smoke.ps1
```
