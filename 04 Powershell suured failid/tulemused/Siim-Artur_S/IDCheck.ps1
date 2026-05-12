<#
.SYNOPSIS
    Kontrollib ID-tarkvara uuendusi ja teavitab, kui uus versioon on saadaval.

.DESCRIPTION
    Pärib uusima versiooni installer.id.ee veebilehelt, võrdleb Windowsi
    registris oleva paigaldatud versiooniga ja saadab teate eelmise tunni
    Saada-Teavitus mooduli kaudu, kui uuendus on vajalik.

.PARAMETER KriitilineErinevus
    Mitme peaversiooni erinevuse korral saadetakse Critical, mitte Warning.
    Vaikimisi 2.

.PARAMETER TeataAjakohasusest
    Kui määratud, saadab Info-teate ka siis, kui tarkvara on ajakohane.
    Muidu vaikib.

.EXAMPLE
    .\kontrolli-id-tarkvara.ps1

.EXAMPLE
    .\kontrolli-id-tarkvara.ps1 -TeataAjakohasusest -Verbose
#>
[CmdletBinding()]
param(
    [int]$KriitilineErinevus = 2,
    [switch]$TeataAjakohasusest
)

# 1. Veebist versiooni pärimine
$SK_URL = "https://installer.id.ee/media/win/"
try {
    $leht = Invoke-WebRequest -Uri $SK_URL -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Error "Ei saanud ühendust id.ee lehega."
    return
}

# Regex mustri parandus (lisasin igaks juhuks alguse)
$muster = 'Open-EID-(\d+\.\d+\.\d+\.\d+)\.exe'
$vasted = [regex]::Matches($leht.Content, $muster)

if ($vasted.Count -eq 0) {
    Write-Error "Ei leidnud veebilehelt ühtegi versiooni mustriga $muster"
    return
}

$versioonid = $vasted | ForEach-Object { [Version]$_.Groups[1].Value } | Sort-Object -Descending
$uusim = $versioonid[0]
Write-Host "Uusim saadaval: $uusim" -ForegroundColor Cyan

# 2. Kohaliku versiooni leidmine registrist
$uninstallTeed = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$paigaldatud = Get-ItemProperty $uninstallTeed -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -match "Open-EID|Estonian ID" } |
               Select-Object -First 1

$kohalik = $null
if ($paigaldatud) {
    $kohalik = [Version]$paigaldatud.DisplayVersion
    Write-Host "Kohalik versioon: $kohalik" -ForegroundColor Yellow
} else {
    Write-Host "Open-EID pole paigaldatud" -ForegroundColor Red
}

$staatus = ""
$severity = ""
$sõnum = ""

if ($null -eq $kohalik) {
    $staatus   = "POLE_PAIGALDATUD"
    $severity  = "Warning"
    $sõnum     = "Open-EID pole paigaldatud. Uusim saadaval: $uusim"
}
elseif ($kohalik -eq $uusim) {
    $staatus   = "OK"
    $severity  = "Info"
    $sõnum     = "Open-EID $kohalik on ajakohane."
}

elseif (($uusim.Major - $kohalik.Major) -ge $KriitilineErinevus) {
    $staatus   = "PALJU_VANEM"
    $severity  = "Critical"
    $sõnum     = "Open-EID $kohalik on oluliselt vananenud! Uusim: $uusim. Uuenda kohe!"
}
else {
    $staatus   = "AEGUNUD"
    $severity  = "Warning"
    $sõnum     = "Open-EID uuendus saadaval: $kohalik -> $uusim"
}

Write-Host "Staatus: $staatus" -ForegroundColor White

# 4. Mooduli laadimine ja saatmine
# Veendu, et webhook.psm1 on samas kaustas
$moodul = Join-Path $PSScriptRoot "webhook.psm1"

if (-not (Test-Path $moodul)) {
    Write-Error "Moodulit ei leitud asukohast: $moodul"
    return # Kasutame returni, et skript ei crashiks
}

Import-Module $moodul -Force

# Otsustame, kas saata teavitus
if ($staatus -ne "OK" -or $TeataAjakohasusest) {
    Send-AlertMessage -Message $sõnum -Severity $severity -Source "ID-tarkvara monitor"
    Write-Host "Teavitus saadetud Discordi." -ForegroundColor Green
}