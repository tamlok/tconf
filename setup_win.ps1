# Install utilities on Windows for development
# Le Tan (tamlokveer at gmail.com)
# https://github.com/tamlok/tnvim

param([switch]$Force=$false, [string]$WorkingDirectory='')

function Main
{
    Write-Host 'Installing utilities on Windows for development...'

    if ($WorkingDirectory -ne '') {
        Set-Location -Path "$WorkingDirectory"
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

    Scoop-Install -command "wezterm" -package "wezterm-nightly"

    Scoop-Install -command "gtags" -package "global"

    Scoop-Install -command "rg" -package "ripgrep"

    Scoop-Install -command "ctags" -package "universal-ctags"

    Scoop-Install -command "python3" -package "python"

    Scoop-Install -command "clangd" -package "llvm"

    Scoop-Install -command "git" -package "git"

    $newNvy = Scoop-Install -command "nvy" -package "nvy"
    if ($newNvy) {
        $CMD = "start /b nvy"
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines("C:\Windows\nvyb.cmd", $CMD, $Utf8NoBomEncoding)
    }

    python3 -m pip install --user --upgrade pynvim

    New-Item -Force -ItemType HardLink -Path "$HOME/.wezterm.lua" -Target "wezterm.lua"
    New-Item -Force -ItemType HardLink -Path "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Target "terminal\settings.json"
    New-Item -Force -ItemType HardLink -Path "$HOME\AppData\Roaming\nushell\env.nu" -Target "nushell\env.nu"
    New-Item -Force -ItemType HardLink -Path "$HOME\AppData\Roaming\nushell\config.nu" -Target "nushell\config.nu"
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
