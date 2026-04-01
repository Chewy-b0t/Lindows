# Quick Setup Guide

## One-Line Install (PowerShell)

```powershell
git clone https://github.com/Chewy-b0t/Lindows.git && cd Lindows && .\install.ps1
```

## Manual Install

1. **Clone the repo:**
   ```powershell
   git clone https://github.com/Chewy-b0t/Lindows.git
   cd Lindows
   ```

2. **Run the installer:**
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\install.ps1
   ```

3. **Open a new terminal** and test:
   ```powershell
   ls
   grep "text" file.txt
   ```

## Uninstall

```powershell
cd Lindows
.\uninstall.ps1
```

## Verify Installation

```powershell
.\tests\smoke.ps1
```

## What You Get

| Command | What It Does |
|---------|--------------|
| `ls`, `ll`, `la` | List files (with details/all files) |
| `grep` | Search text in files |
| `cat`, `head`, `tail` | View file contents |
| `cp`, `mv`, `rm` | Copy, move, delete files |
| `mkdir`, `touch` | Create folders/files |
| `pwd`, `which`, `find` | Navigation and search |
| `ps`, `df`, `du` | System info |
| `..`, `...`, `....` | Quick parent directory navigation |
| `mkcd <dir>` | Create and enter directory in one command |

## Need Help?

- Full README: [`README.md`](README.md)
- Report issues: [GitHub Issues](https://github.com/Chewy-b0t/Lindows/issues)
