# Update opencode's GitHub Copilot headers to match the installed Copilot CLI.
#
# What it does:
#   1. Upgrades the GitHub Copilot CLI via winget (unless -SkipCliUpgrade).
#   2. Reads the installed CLI version via `copilot --version`.
#   3. Updates the three Copilot headers in opencode\opencode.json so the
#      User-Agent tracks the installed CLI version (the dynamic value), while
#      Copilot-Integration-Id and X-GitHub-Api-Version are enforced constants.
#   4. Copies the updated opencode.json to the user config folder
#      (%USERPROFILE%\.config\opencode), mirroring setup.ps1.
#
# The `copilot-developer-cli` integration id is what unlocks the extended model
# catalog and avoids "model is not supported" errors.

param(
    [switch]$SkipCliUpgrade = $false,
    [string]$ApiVersion = '2026-06-01',
    [switch]$NoDeploy = $false
)

$ErrorActionPreference = 'Stop'

$IntegrationId = 'copilot-developer-cli'
$WingetId = 'GitHub.Copilot'
$RepoConfig = Join-Path $PSScriptRoot 'opencode\opencode.json'
$UserConfigDir = Join-Path $env:USERPROFILE '.config\opencode'

function Test-CommandExists
{
    Param([string]$command)
    return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

# 1. Upgrade the Copilot CLI via winget (non-fatal on "already latest").
if (-Not $SkipCliUpgrade) {
    if (Test-CommandExists 'winget') {
        Write-Host "Upgrading GitHub Copilot CLI via winget ($WingetId)..."
        # winget returns a non-zero exit code when no upgrade is applicable; that
        # is not an error for us, so don't let it abort the script.
        try {
            & winget upgrade --id $WingetId -e --accept-source-agreements --accept-package-agreements
        } catch {
            Write-Host "winget upgrade reported: $($_.Exception.Message) (continuing)"
        }
        Write-Host "winget upgrade step finished (exit code $LASTEXITCODE; non-zero is OK if already latest)."
    } else {
        Write-Host "winget not found; skipping CLI upgrade and using the installed CLI."
    }
} else {
    Write-Host "-SkipCliUpgrade set; using the installed CLI as-is."
}

# 2. Read the installed CLI version.
if (-Not (Test-CommandExists 'copilot')) {
    throw "GitHub Copilot CLI ('copilot') not found on PATH. Install it before running this script."
}
$raw = (& copilot --version 2>&1 | Out-String)
if ($raw -notmatch '(\d+\.\d+\.\d+)') {
    throw "Could not parse a version from 'copilot --version' output: $($raw.Trim())"
}
$version = $Matches[1]
# Match the real CLI User-Agent: aS() in the bundle returns `${Wze(name)}/${version}...`
# where Wze strips the npm scope ("@github/copilot" -> "copilot"). We carry the
# identifying core `copilot/<version>` (the telemetry parenthetical is omitted).
$userAgent = "copilot/$version"
Write-Host "Installed Copilot CLI version: $version -> User-Agent: $userAgent"

# 3. Load and validate the repo config (do not invent the file).
if (-Not (Test-Path -LiteralPath $RepoConfig)) {
    throw "Config file not found: $RepoConfig"
}
$originalText = [System.IO.File]::ReadAllText($RepoConfig)
$json = $originalText | ConvertFrom-Json
$headers = $json.provider.'github-copilot'.options.headers
if ($null -eq $headers) {
    throw "Expected provider.github-copilot.options.headers in $RepoConfig but it is missing."
}

# 4. Surgically replace the three header values (preserve formatting -> minimal diff).
$targets = [ordered]@{
    'Copilot-Integration-Id' = $IntegrationId
    'X-GitHub-Api-Version'   = $ApiVersion
    'User-Agent'             = $userAgent
}
$text = $originalText
foreach ($key in $targets.Keys) {
    $value = $targets[$key]
    $pattern = '("' + [regex]::Escape($key) + '"\s*:\s*")[^"]*(")'
    $matchCount = ([regex]::Matches($text, $pattern)).Count
    if ($matchCount -ne 1) {
        throw "Expected exactly 1 occurrence of header '$key' in $RepoConfig but found $matchCount."
    }
    $replacement = '${1}' + $value.Replace('$', '$$') + '${2}'
    $text = [regex]::Replace($text, $pattern, $replacement)
}

# 5. Re-validate and write back (UTF-8 no BOM, LF preserved).
$check = $text | ConvertFrom-Json
$checkHeaders = $check.provider.'github-copilot'.options.headers
if ($checkHeaders.'Copilot-Integration-Id' -ne $IntegrationId -or
    $checkHeaders.'X-GitHub-Api-Version' -ne $ApiVersion -or
    $checkHeaders.'User-Agent' -ne $userAgent) {
    throw "Post-update validation failed: header values do not match the intended targets."
}

if ($text -eq $originalText) {
    Write-Host "opencode.json already up to date; no changes written."
} else {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($RepoConfig, $text, $utf8NoBom)
    Write-Host "Updated headers in $RepoConfig"
}

# 6. Deploy to the user config folder (mirror setup.ps1).
if (-Not $NoDeploy) {
    New-Item -ItemType Directory -Force -Path $UserConfigDir | Out-Null
    $dest = Join-Path $UserConfigDir 'opencode.json'
    Copy-Item -Force -LiteralPath $RepoConfig -Destination $dest
    Write-Host "Deployed opencode.json to $dest"
} else {
    Write-Host "-NoDeploy set; skipped copying to $UserConfigDir."
}

# 7. Summary.
Write-Host ""
Write-Host "Done."
Write-Host "  Copilot-Integration-Id : $IntegrationId"
Write-Host "  X-GitHub-Api-Version   : $ApiVersion"
Write-Host "  User-Agent             : $userAgent"
