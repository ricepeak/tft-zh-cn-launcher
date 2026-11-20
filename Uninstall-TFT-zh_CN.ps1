[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TFT-zh_CN-Launcher')).TrimEnd('\')
$desktopPath = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath 'TFT_SC.lnk'

try {
    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }

    $currentRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path)).TrimEnd('\')
    if ($currentRoot -ne $expectedRoot) {
        throw "Safety check stopped removal of unexpected folder: $currentRoot"
    }

    if (Test-Path -LiteralPath $expectedRoot -PathType Container) {
        Remove-Item -LiteralPath $expectedRoot -Recurse -Force
    }

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        'TFT zh_CN launcher was removed. Riot and TFT files were not deleted.',
        'TFT zh_CN launcher',
        'OK',
        'Information'
    ) | Out-Null
}
catch {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Uninstall failed.`n`n$($_.Exception.Message)",
        'TFT zh_CN launcher',
        'OK',
        'Error'
    ) | Out-Null
    exit 1
}
