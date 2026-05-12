[CmdletBinding()]
param(
    [int]$CriticalMajorDifference = 2
)

<#
.SYNOPSIS
Kontrollib ID-tarkvara versiooni ja saadab teavituse, kui uuendus on vajalik.

.DESCRIPTION
Võrdleb RIA serveris saadaval olevat Open-EID versiooni kohaliku paigaldusega.
Kasutab teavituste saatmiseks Saada-Teavitus.psm1 moodulit.
#>

Import-Module "$PSScriptRoot\Saada-Teavitus.psm1" -Force

# --- Konstandid ---
$Url = "https://installer.id.ee/media/win/"
$RegexPattern = "Open-EID-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.exe"

Write-Host "Kontrollin ID-tarkvara versiooni..."

# --- Samm 1: lae leht ---
try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Warning "Veebipäring ebaõnnestus: $($_.Exception.Message)"
    Send-AlertMessage -Message "ID-tarkvara versiooni kontroll ebaõnnestus: $($_.Exception.Message)" -Severity Warning
    return
}

# --- Samm 2: leia uusim versioon regexiga ---
$matches = [regex]::Matches($response.Content, $RegexPattern)

if ($matches.Count -eq 0) {
    Write-Warning "Ei leidnud Open-EID installerit lehelt."
    return
}

$versions = $matches | ForEach-Object {
    [Version]$_.Groups[1].Value
}

$uusim = $versions | Sort-Object -Descending | Select-Object -First 1

# --- Samm 3: leia kohalik versioon registrist ---
$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$kohalikObj = Get-ItemProperty -Path $regPaths -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -match "Open-EID Metapackage|eID software"
    } |
    Sort-Object {
        try { [Version]$_.DisplayVersion } catch { [Version]"0.0.0.0" }
    } -Descending |
    Select-Object -First 1 DisplayName, DisplayVersion

[Version]$kohalik = $null
if ($kohalikObj) {
    [Version]$kohalik = $kohalikObj.DisplayVersion
}


# --- Samm 4: väljundi tekst ---
if ($kohalik) {
    $kohalikTekst = $kohalik
} else {
    $kohalikTekst = "pole paigaldatud"
}

Write-Host ("  Kohalik versioon:     {0}" -f $kohalikTekst)
Write-Host ("  Uusim saadaval:       {0}" -f $uusim)

# --- Samm 5: staatus ---
if (-not $kohalik) {
    $staatus = "POLE_PAIGALDATUD"
    $severity = "Warning"
}
elseif ($kohalik -eq $uusim) {
    $staatus = "OK"
    $severity = "Info"
}
else {
    $majorDiff = $uusim.Major - $kohalik.Major
    if ($majorDiff -gt $CriticalMajorDifference) {
        $staatus = "PALJU_VANEM"
        $severity = "Critical"
    }
    else {
        $staatus = "AEGUNUD"
        $severity = "Warning"
    }
}

Write-Host ("  Staatus:              {0}" -f $staatus)

# --- Samm 6: teavitused ---
switch ($staatus) {
    "POLE_PAIGALDATUD" {
        Send-AlertMessage -Message "ID-tarkvara ei ole paigaldatud. Uusim versioon: $uusim" -Severity $severity
    }
    "AEGUNUD" {
        Send-AlertMessage -Message "ID-tarkvara on aegunud. Kohalik: $kohalik, uusim: $uusim" -Severity $severity
    }
    "PALJU_VANEM" {
        Send-AlertMessage -Message "ID-tarkvara on oluliselt vananenud! Kohalik: $kohalik, uusim: $uusim" -Severity $severity
    }
    "OK" {
        Send-AlertMessage -Message "ID-tarkvara on ajakohane: $kohalik" -Severity $severity
    }
}
