<#
.SYNOPSIS
Kontrollib Open-EID versiooni ja saadab teavituse, kui uuendus on saadaval.

.DESCRIPTION
Võrdleb RIA serveris olevat uusimat Open-EID versiooni
kohalikult paigaldatud versiooniga (registrist).
Saadab teavituse Saada-Teavitus mooduli kaudu.

#>

[CmdletBinding()]
param(
    [int]$KriitilineErinevus = 2,
    [switch]$TeataAjakohasusest
)

# -----------------------------
# KONSTANDID
# -----------------------------
$SK_URL = "https://installer.id.ee/media/win/"
$MUSTER = 'Open-EID-(\d+\.\d+\.\d+\.\d+)\.exe'

# -----------------------------
# LAE MOODUL
# -----------------------------
$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"

if (-not (Test-Path $moodul)) {
    throw "Saada-Teavitus.psm1 puudub"
}

Import-Module $moodul -Force

# -----------------------------
# 1. VEEBIST UUSIM VERSIOON
# -----------------------------
try {
    $leht = Invoke-WebRequest -Uri $SK_URL -UseBasicParsing -ErrorAction Stop
}
catch {
    Send-AlertMessage -Message "ID kontroll ebaõnnestus: $($_.Exception.Message)" -Severity Warning -Source "ID-check"
    return
}

$versioonid = [regex]::Matches($leht.Content, $MUSTER) |
    ForEach-Object { [Version]$_.Groups[1].Value } |
    Sort-Object -Descending

if (-not $versioonid) {
    throw "Ei leitud ühtegi versiooni"
}

$uusim = $versioonid[0]

# -----------------------------
# 2. KOHALIK VERSIOON (REGISTER)
# -----------------------------
$paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$paigaldatud = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match "Open-EID|Estonian ID" } |
    Select-Object -First 1

if ($paigaldatud) {
    $kohalik = [Version]$paigaldatud.DisplayVersion
} else {
    $kohalik = $null
}

# -----------------------------
# 3. STAATUS
# -----------------------------
if (-not $kohalik) {
    $staatus = "POLE_PAIGALDATUD"
    $severity = "Warning"
    $sonum = "Open-EID pole paigaldatud. Uusim: $uusim"
}
elseif ($kohalik -eq $uusim) {
    $staatus = "OK"
    $severity = "Info"
    $sonum = "Open-EID on ajakohane ($kohalik)"

    if (-not $TeataAjakohasusest) {
        $saada = $false
    } else {
        $saada = $true
    }
}
else {
    $vahe = $uusim.Major - $kohalik.Major

    if ($vahe -ge $KriitilineErinevus) {
        $staatus = "PALJU_VANEM"
        $severity = "Critical"
    }
    else {
        $staatus = "AEGUNUD"
        $severity = "Warning"
    }

    $sonum = "Open-EID uuendus saadaval ($kohalik → $uusim)"
    $saada = $true
}

# -----------------------------
# 4. VÄLJUND
# -----------------------------
Write-Host "=== ID CHECK ==="
Write-Host "Kohalik versioon: $kohalik"
Write-Host "Uusim versioon:   $uusim"
Write-Host "Staatus:          $staatus"

# -----------------------------
# 5. TEAVITUS
# -----------------------------
if ($staatus -ne "OK" -or $TeataAjakohasusest) {
    Send-AlertMessage `
        -Message $sonum `
        -Severity $severity `
        -Source "ID-tarkvara monitor"
}