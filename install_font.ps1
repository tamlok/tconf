# Install fonts from a given folder on Windows

function Set-FontReplacementAfterReboot
{
    Param([string]$source, [string]$destination)

    if (-Not ('FontInstallerNativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;

public static class FontInstallerNativeMethods
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveFileEx(string existingFileName, string newFileName, int flags);
}
'@
    }

    $pendingFile = "$destination.update"
    Copy-Item -LiteralPath $source -Destination $pendingFile -Force -ErrorAction Stop

    # MOVEFILE_REPLACE_EXISTING | MOVEFILE_DELAY_UNTIL_REBOOT
    $flags = 0x1 -bor 0x4
    if (-Not [FontInstallerNativeMethods]::MoveFileEx($pendingFile, $destination, $flags)) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Remove-Item -LiteralPath $pendingFile -Force -ErrorAction SilentlyContinue
        throw [ComponentModel.Win32Exception]::new($errorCode)
    }

    Write-Host "Font is in use; replacement scheduled for next reboot: $(Split-Path -Leaf $destination)"
}

function Install-Font
{
    param([string]$fontFolder, [switch]$Force=$false)

    if (!(Test-Path $fontFolder)) {
        Write-Error "Fail to locate source font folder $fontFolder"
        return
    }

    $objShell = New-Object -ComObject Shell.Application
    $objFolder = $objShell.Namespace(0x14)

    $Fonts = Get-ChildItem -Path $fontFolder -Recurse -Include '*.ttf','*.ttc','*.otf'
    $Fonts | ForEach-Object {
        $destFile = "$HOME\AppData\Local\Microsoft\Windows\Fonts\$($_.Name)"
        if (Test-Path $destFile) {
            if ($Force) {
                $sourceFile = $_.FullName
                Write-Host "Replacing font $($_.Name)"
                try {
                    Copy-Item -LiteralPath $sourceFile -Destination $destFile -Force -ErrorAction Stop
                } catch [System.IO.IOException] {
                    Set-FontReplacementAfterReboot -source $sourceFile -destination $destFile
                }
            } else {
                Write-Host "Font already exists: $($_.Name)"
            }
        } else {
            Write-Host "Installing font $($_.Name)"
            $objFolder.CopyHere($_.FullName, 4 + 16)
        }
    }
}
