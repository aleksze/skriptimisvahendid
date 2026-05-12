<#
.SYNOPSIS
    Kontrollib ID-tarkvara versiooni ja teavitab kui uuendus on saadaval.

.DESCRIPTION
    Pärib uusima Open-EID versiooni installer.id.ee lehelt, võrdleb registris
    oleva versiooniga ja saadab teavituse Saada-Teavitus mooduli kaudu.

.PARAMETER KriitilineErinevus
    Mitu peaversiooni vahet loetakse kriitiliseks. Vaikimisi 2.

.EXAMPLE
    .\kontrolli-id-tarkvara.ps1

.EXAMPLE
    .\kontrolli-id-tarkvara.ps1 -Verbose
#>

[CmdletBinding()]
param(
    [int]$KriitilineErinevus = 2
)

$SK_URL = "https://installer.id.ee/media/win/"
$MUSTER = 'Open-EID-(\d+\.\d+\.\d+\.\d+)\.exe'

Write-Host "Kontrollin ID-tarkvara versiooni..."

$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"
if (-not (Test-Path $moodul)) {
    throw "Saada-Teavitus.psm1 puudub!"
}
Import-Module $moodul -Force

try {
    $leht = Invoke-WebRequest -Uri $SK_URL -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Warning "Veebipäring ebaõnnestus: $($_.Exception.Message)"
    Send-AlertMessage -Message "ID-tarkvara kontroll ebaõnnestus: $($_.Exception.Message)" `
                      -Severity Warning -Source "ID-tarkvara monitor"
    exit 1
}

$versioonid = [regex]::Matches($leht.Content, $MUSTER) |
    ForEach-Object { [Version]$_.Groups[1].Value } |
    Sort-Object -Descending

if (-not $versioonid) {
    throw "Ei leidnud ühtegi versiooni lehelt"
}

$uusim = $versioonid[0]

$uninstallTeed = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$paigaldatud = Get-ItemProperty $uninstallTeed -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match "^Open-EID Metapackage$|^eID software$" } |
    Select-Object -First 1

if ($paigaldatud) {
    $kohalik = [Version]$paigaldatud.DisplayVersion
} else {
    $kohalik = $null
}

if (-not $kohalik) {
    $staatus  = "POLE_PAIGALDATUD"
    $severity = "Warning"
    $sonum    = "Open-EID pole paigaldatud. Uusim: $uusim"
}
elseif ($kohalik -eq $uusim) {
    $staatus  = "OK"
    $severity = "Info"
    $sonum    = "Open-EID on ajakohane ($kohalik)"
}
elseif (($uusim.Major - $kohalik.Major) -ge $KriitilineErinevus) {
    $staatus  = "PALJU_VANEM"
    $severity = "Critical"
    $sonum    = "Open-EID väga vana: $kohalik -> $uusim"
}
else {
    $staatus  = "AEGUNUD"
    $severity = "Warning"
    $sonum    = "Open-EID uuendus saadaval: $kohalik -> $uusim"
}

Write-Host "  Kohalik: $kohalik"
Write-Host "  Uusim:   $uusim"
Write-Host "  Staatus: $staatus"

if ($staatus -ne "OK") {
    Send-AlertMessage -Message $sonum -Severity $severity -Source "ID-tarkvara monitor"
}
