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

    if (!(Check-Command-Exists "scoop")) {
        irm get.scoop.sh | iex

        scoop bucket add extras
        scoop bucket add versions
    }

    Scoop-Install -command "nvim" -package "neovim-nightly"

    Scoop-Install -command "wezterm" -package "wezterm"

    Scoop-Install -command "gtags" -package "global"

    Scoop-Install -command "rg" -package "ripgrep"

    Scoop-Install -command "ctags" -package "universal-ctags"

    Scoop-Install -command "python" -package "python"

    Scoop-Install -command "clangd" -package "llvm"

    Scoop-Install -command "git" -package "git"

    python3 -m pip install --user --upgrade pynvim

    copy .\.wezterm.lua  $HOME\.wezterm.lua
}

function Check-Admin
{
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
    $myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

    if ($myWindowsPrincipal.IsInRole($adminRole)) {
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
        return
    }

    scoop install $package
}

Main
