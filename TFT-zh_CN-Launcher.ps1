[CmdletBinding()]
param(
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$targetLocale = 'zh_CN'
$metadataPath = 'C:\ProgramData\Riot Games\Metadata\teamfighttactics.live\teamfighttactics.live.product_settings.yaml'
$appDataRoot = Join-Path $env:LOCALAPPDATA 'TFT-zh_CN-Launcher'
$logPath = Join-Path $appDataRoot 'launcher.log'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$processNames = @(
    'RiotClientServices',
    'RiotClientUx',
    'RiotClientUxRender',
    'TFTClient',
    'TFTClient-Win64-Shipping',
    'BootstrapPackagedGame',
    'LeagueClient',
    'LeagueClientUx',
    'LeagueClientUxRender',
    'League of Legends'
)

if (-not (Test-Path -LiteralPath $appDataRoot)) {
    New-Item -ItemType Directory -Path $appDataRoot -Force | Out-Null
}

function Write-LauncherLog {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message" -Encoding UTF8
}

function Get-YamlValue {
    param([string]$Text, [string]$Key)
    $match = [regex]::Match($Text, "(?m)^\s*$([regex]::Escape($Key)):\s*['`"]?(.+?)['`"]?\s*$")
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Find-RiotClient {
    $candidates = New-Object System.Collections.Generic.List[string]
    $installsPath = Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json'
    if (Test-Path -LiteralPath $installsPath -PathType Leaf) {
        try {
            $installs = [System.IO.File]::ReadAllText($installsPath) | ConvertFrom-Json
            foreach ($path in @($installs.rc_live, $installs.patchlines.KeystoneFoundationLiveWin, $installs.rc_default)) {
                if (-not [string]::IsNullOrWhiteSpace($path)) {
                    $candidates.Add($path.Replace('/', '\'))
                }
            }
        }
        catch {
            Write-LauncherLog 'Riot installation registry could not be read; trying metadata paths.'
        }
    }

    if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        try {
            $metadata = [System.IO.File]::ReadAllText($metadataPath)
            $TFTRoot = Get-YamlValue -Text $metadata -Key 'product_install_full_path'
            $productRoot = Get-YamlValue -Text $metadata -Key 'product_install_root'
            if (-not [string]::IsNullOrWhiteSpace($productRoot)) {
                $candidates.Add((Join-Path $productRoot.Replace('/', '\') 'Riot Client\RiotClientServices.exe'))
            }
            if (-not [string]::IsNullOrWhiteSpace($TFTRoot)) {
                $TFTRoot = $TFTRoot.Replace('/', '\').TrimEnd('\')
                $candidates.Add((Join-Path (Split-Path -Parent $TFTRoot) 'Riot Client\RiotClientServices.exe'))
            }
        }
        catch [System.IO.IOException] {
            # Riot may replace metadata during discovery; the installation registry remains usable.
        }
    }

    $riotClient = $candidates |
        Select-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($riotClient)) {
        throw 'RiotClientServices.exe could not be located from Riot installation records or metadata.'
    }
    Write-LauncherLog "Located Riot Client: $riotClient"
    return $riotClient
}

function Set-ActiveTFTLocale {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $false
    }

    try {
        $original = [System.IO.File]::ReadAllText($metadataPath)
        $locale = Get-YamlValue -Text $original -Key 'locale'
        if ($locale -eq $targetLocale) {
            return $false
        }

        $updated = [regex]::Replace(
            $original,
            '(?m)^(\s*locale:\s*).+$',
            "`$1`"$targetLocale`""
        )
        if ($updated -eq $original) {
            return $false
        }

        [System.IO.File]::WriteAllText($metadataPath, $updated, $utf8NoBom)
        Write-LauncherLog "Restored active metadata locale to $targetLocale."
        return $true
    }
    catch [System.IO.IOException] {
        # Riot briefly removes or locks the file while replacing it.
        return $false
    }
}

function Get-ActiveTFTLocale {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $null
    }

    try {
        $metadata = [System.IO.File]::ReadAllText($metadataPath)
        return Get-YamlValue -Text $metadata -Key 'locale'
    }
    catch [System.IO.IOException] {
        # Riot briefly removes or locks the file while replacing it.
        return $null
    }
}

function Get-MetadataLastWriteUtc {
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return [datetime]::MinValue
    }

    try {
        return (Get-Item -LiteralPath $metadataPath).LastWriteTimeUtc
    }
    catch [System.IO.IOException] {
        return [datetime]::MinValue
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        return [datetime]::MinValue
    }
}

function Test-MatchRunning {
    return @(Get-Process -Name 'TFTClient', 'TFTClient-Win64-Shipping', 'League of Legends' -ErrorAction SilentlyContinue).Count -gt 0
}

function Test-TFTClientRunning {
    return @(Get-Process -Name 'TFTClient', 'BootstrapPackagedGame', 'LeagueClient', 'LeagueClientUx', 'LeagueClientUxRender' -ErrorAction SilentlyContinue).Count -gt 0
}

function Restart-RiotClientOnce {
    param([string]$RiotClient)

    Write-LauncherLog 'EN update state detected; restarting Riot Client once after restoring zh_CN.'
    @('TFTClient', 'BootstrapPackagedGame', 'RiotClientUxRender', 'RiotClientUx', 'RiotClientServices') | ForEach-Object {
        Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $deadline = (Get-Date).AddSeconds(8)
    do {
        $riotProcesses = @(
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $_.ProcessName -in @('TFTClient', 'BootstrapPackagedGame', 'RiotClientServices', 'RiotClientUx', 'RiotClientUxRender') }
        )
        if ($riotProcesses.Count -eq 0) {
            break
        }
        $riotProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    Start-Sleep -Seconds 2
    Start-Process -FilePath $RiotClient
    Write-LauncherLog 'Riot Client restarted normally; active-locale watcher is still running.'
}

function Test-RiotOrTFTRunning {
    return @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -in $processNames }
    ).Count -gt 0
}

try {
    Write-LauncherLog 'Launcher started.'
    $riotClient = Find-RiotClient

    if ($NoLaunch) {
        Write-LauncherLog 'Validation completed without launching Riot Client.'
        exit 0
    }

    $alreadyRunning = Test-RiotOrTFTRunning
    $baselineMetadataWriteUtc = Get-MetadataLastWriteUtc
    $initialLocale = Get-ActiveTFTLocale
    $restartPerformed = $false
    if (-not $alreadyRunning) {
        Start-Process -FilePath $riotClient
        Write-LauncherLog 'Riot Client started normally.'
    }
    else {
        Write-LauncherLog 'Attached to the existing Riot/TFT session.'
    }

    if (-not (Test-MatchRunning)) {
        Set-ActiveTFTLocale | Out-Null
    }

    if ($alreadyRunning -and $initialLocale -eq 'en_US' -and -not (Test-TFTClientRunning) -and -not (Test-MatchRunning)) {
        Restart-RiotClientOnce -RiotClient $riotClient
        $restartPerformed = $true
    }

    Write-LauncherLog 'Watching active metadata locale while Riot or TFT is open; pausing during matches.'

    $noProcessSince = $null
    $matchWasRunning = $false
    while ($true) {
        if (Test-MatchRunning) {
            if (-not $matchWasRunning) {
                Write-LauncherLog 'TFT match started; locale monitoring paused.'
                $matchWasRunning = $true
            }
            $noProcessSince = $null
            Start-Sleep -Milliseconds 250
            continue
        }
        if ($matchWasRunning) {
            Write-LauncherLog 'TFT match ended; locale monitoring resumed.'
            $matchWasRunning = $false
        }

        $observedLocale = Get-ActiveTFTLocale
        $metadataWriteUtc = Get-MetadataLastWriteUtc
        $freshEnReset = (
            -not $alreadyRunning -and
            -not $restartPerformed -and
            $observedLocale -eq 'en_US' -and
            $metadataWriteUtc -gt $baselineMetadataWriteUtc
        )

        if (Test-MatchRunning) {
            continue
        }
        Set-ActiveTFTLocale | Out-Null

        if ($freshEnReset -and -not (Test-TFTClientRunning) -and -not (Test-MatchRunning)) {
            Restart-RiotClientOnce -RiotClient $riotClient
            $restartPerformed = $true
        }

        if (Test-RiotOrTFTRunning) {
            $noProcessSince = $null
        }
        elseif ($null -eq $noProcessSince) {
            $noProcessSince = Get-Date
        }
        elseif ((Get-Date) -ge $noProcessSince.AddSeconds(10)) {
            Write-LauncherLog 'Riot and TFT are closed; locale monitoring finished.'
            break
        }

        Start-Sleep -Milliseconds 250
    }

}
catch {
    Write-LauncherLog "ERROR: $($_.Exception.Message)"
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Could not keep TFT in Simplified Chinese.`n`n$($_.Exception.Message)`n`nLog: $logPath",
        'TFT zh_CN launcher',
        'OK',
        'Error'
    ) | Out-Null
    exit 1
}
