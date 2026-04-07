# Install utilities on Windows for development
# Le Tan (tamlokveer at gmail.com)
# https://github.com/tamlok/tnvim

param([string]$Action='', [switch]$Force=$false, [string]$WorkingDirectory='')

# Remove a file if it is a symlink or hardlink (link count > 1), so Copy-Item creates a fresh independent copy
function Remove-If-Link
{
    Param([string]$path)
    if (-Not (Test-Path -Path $path)) { return }
    $item = Get-Item -Path $path -Force
    # Symlink or reparse point
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Write-Host "Removing old symlink: $path"
        Remove-Item -Path $path -Force
        return
    }
    # Hardlink: NTFS file with more than 1 link
    if (-Not $item.PSIsContainer) {
        $links = @(fsutil hardlink list $path)
        if ($links.Count -gt 1) {
            Write-Host "Removing old hardlink: $path"
            Remove-Item -Path $path -Force
        }
    }
}

# Remove a directory junction/symlink so it can be replaced with a real directory
function Remove-If-Junction
{
    Param([string]$path)
    if (-Not (Test-Path -Path $path)) { return }
    $item = Get-Item -Path $path -Force
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Write-Host "Removing old junction: $path"
        # Remove only the junction link itself, not the target contents
        $item.Delete()
    }
}

function Setup-Config
{
    # Individual config files - ensure parent directories exist, use $PSScriptRoot for sources
    # Remove old hardlinks/symlinks first so Copy-Item creates independent copies
    Remove-If-Link "$HOME\.wezterm.lua"
    Copy-Item -Force "$PSScriptRoot\wezterm.lua" "$HOME\.wezterm.lua"

    $terminalFolder = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    if (Test-Path -Path "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe") {
        New-Item -ItemType Directory -Force -Path $terminalFolder | Out-Null
        Remove-If-Link "$terminalFolder\settings.json"
        Copy-Item -Force "$PSScriptRoot\terminal\settings.json" "$terminalFolder\settings.json"
    }

    $nushellFolder = "$HOME\AppData\Roaming\nushell"
    New-Item -ItemType Directory -Force -Path $nushellFolder | Out-Null
    Remove-If-Link "$nushellFolder\env.nu"
    Copy-Item -Force "$PSScriptRoot\nushell\env.nu" "$nushellFolder\env.nu"
    Remove-If-Link "$nushellFolder\config.nu"
    Copy-Item -Force "$PSScriptRoot\nushell\config.nu" "$nushellFolder\config.nu"

    # Directory configs - remove old junctions/symlinks, then copy tracked config files only
    $claudeFolder = "$env:USERPROFILE\.claude"
    Remove-If-Junction $claudeFolder
    New-Item -ItemType Directory -Force -Path $claudeFolder | Out-Null
    Write-Host "Copying config to $claudeFolder"
    Copy-Item -Force "$PSScriptRoot\claude\CLAUDE.md" $claudeFolder
    Copy-Item -Force "$PSScriptRoot\claude\settings.json" $claudeFolder

    $configFolder = "$env:USERPROFILE\.config"
    New-Item -ItemType Directory -Force -Path $configFolder | Out-Null
    $opencodeFolder = "$configFolder\opencode"
    Remove-If-Junction $opencodeFolder
    New-Item -ItemType Directory -Force -Path $opencodeFolder | Out-Null
    Write-Host "Copying config to $opencodeFolder"
    Copy-Item -Force "$PSScriptRoot\opencode\AGENTS.md" $opencodeFolder
    Copy-Item -Force "$PSScriptRoot\opencode\oh-my-opencode.json" $opencodeFolder
    Copy-Item -Force "$PSScriptRoot\opencode\opencode.json" $opencodeFolder
}

function Setup-Env
{
    # Opencode uses `EDITOR` environment variable to detect the editor
    setx EDITOR "nvim"

    # Add neovim mason bin to user PATH
    $masonBin = "$env:LOCALAPPDATA\nvim-data\mason\bin"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$masonBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$masonBin;$currentPath", "User")
    }
}

function Main
{
    Write-Host 'Installing utilities on Windows for development...'

    if ($WorkingDirectory -ne '') {
        Set-Location -Path "$WorkingDirectory"
    }

    if ($Action -eq 'config') {
        Setup-Config
        return
    }

    . '.\install_font.ps1'

    Install-Fonts

    Refresh-Env

    if (-Not (Check-Command-Exists "scoop")) {
        Write-Host "Installing scoop"
        irm get.scoop.sh | iex

        Refresh-Env
        scoop bucket add extras
        scoop bucket add versions
    }

    Check-Admin

    $newNvim = Scoop-Install -command "nvim" -package "neovim"
    if ($newNvim) {
        Setup-Neovim
    }

    Scoop-Install -command "nu" -package "nu"

    # Scoop-Install -command "wezterm" -package "wezterm-nightly"

    Scoop-Install -command "gtags" -package "global"

    Scoop-Install -command "rg" -package "ripgrep"

    Scoop-Install -command "ctags" -package "universal-ctags"

    Scoop-Install -command "opencode" -package "opencode"

    Scoop-Install -command "python3" -package "python"

    $newNvy = Scoop-Install -command "nvy" -package "nvy"
    if ($newNvy) {
        $CMD = "start /b nvy"
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines("C:\Windows\nvyb.cmd", $CMD, $Utf8NoBomEncoding)
    }

    python3 -m pip install --user --upgrade pynvim

    Setup-Config
    Setup-Env
}

function Is-Admin
{
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
    $myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;
    return $myWindowsPrincipal.IsInRole($adminRole)
}

function Check-Admin
{
    if (Is-Admin) {
        return
    } else {
        Write-Host "Continue as Administrator"

        $arguments = "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($Force) {
            $arguments += ' -Force'
        }
        $arguments += " -WorkingDirectory `"" + (Get-Location).Path + '"'
        if ($Action -ne '') {
            $arguments += " -Action `"$Action`""
        }

        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
        exit 0
    }
}

function Install-Fonts
{
    $fontFolder = (Get-Item '.\fonts').FullName
    Install-Font "$fontFolder"
}

function Check-Command-Exists
{
    Param([string]$command)

    if ((Get-Command $command -ErrorAction SilentlyContinue) -eq $null) {
        return $false
    }

    return $true
}

function Scoop-Install
{
    Param([string]$command, [string]$package)

    if (Check-Command-Exists($command)) {
        Write-Host "$package already exists"
        return $false
    }

    Write-Host "Installing $package"
    scoop install $package
    return $true
}

function Refresh-Env
{
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Process")
}

function Setup-Neovim
{
    Write-Host "Setup NeoVim"
    Refresh-Env
    $nvim = Get-Command 'nvim' -ErrorAction SilentlyContinue
    if ($nvim -eq $null) {
        Write-Host "Failed to locate NeoVim"
        return
    }

    $nvimFolder = (Get-Item $nvim.Path).Directory.FullName
    Write-Host "NeoVim folder: $nvimFolder"

    Add-Neovim-To-Context-Menu $nvimFolder
}

function Add-Neovim-To-Context-Menu
{
    Param([string]$nvimFolder)

    $neovimKeyStr = 'Registry::HKEY_CLASSES_ROOT\*\shell\Neovim'
    if ((Get-Item -LiteralPath "$neovimKeyStr") -eq $null) {
        Write-Host "Create registry key $neovimKeyStr"
        New-Item "$neovimKeyStr" > $null
    }

    $displayName = 'Edit with Neovim'
    Set-ItemProperty -LiteralPath "$neovimKeyStr" -Name '(Default)' -Value "$displayName"
    $icon = "`"$nvimFolder\bin\nvim-qt.exe`""
    Set-ItemProperty -LiteralPath "$neovimKeyStr" -Name 'Icon' -Value "$icon"

    $commandKeyStr = "$neovimKeyStr\command"
    if ((Get-Item -LiteralPath "$commandKeyStr") -eq $null) {
        Write-Host "Create registry key $commandKeyStr"
        New-Item "$commandKeyStr" > $null
    }

    $command = "`"$nvimFolder\bin\nvim-qt.exe`" `"%1`""
    Set-ItemProperty -LiteralPath "$commandKeyStr" -Name '(Default)' -Value "$command"
}

Main
