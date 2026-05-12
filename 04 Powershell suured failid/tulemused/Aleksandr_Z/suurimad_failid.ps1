# ============================================================
# suurimad_failid.ps1
# Leiab 10 kõige suuremat faili ja salvestab CSV faili
# ============================================================

[CmdletBinding()]
param(
    [string]$Path = $HOME,
    [int]$TopN = 10
)

Write-Host "Otsin $TopN kõige suuremat faili kaustas: $Path" -ForegroundColor Cyan

# --- функция для перевода размера ---
function Format-Suurus {
    param([long]$Baite)

    if ($Baite -ge 1GB) {
        return "{0:N1} GB" -f ($Baite / 1GB)
    }
    elseif ($Baite -ge 1MB) {
        return "{0:N1} MB" -f ($Baite / 1MB)
    }
    else {
        return "{0:N1} KB" -f ($Baite / 1KB)
    }
}

# --- 1. найти файлы ---
$failid = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue

# --- 2. сортировка и топ ---
$topFailid = $failid |
    Sort-Object -Property Length -Descending |
    Select-Object -First $TopN

# --- 3. создать результат ---
$tulemus = foreach ($fail in $topFailid) {
    [PSCustomObject]@{
        Tee    = $fail.FullName
        Nimi   = $fail.Name
        Suurus = Format-Suurus -Baite $fail.Length
    }
}

# --- 4. сохранить CSV в папку скрипта ---
$csvPath = Join-Path $PSScriptRoot "suurimad_failid.csv"

$tulemus | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# --- 5. вывод ---
Write-Host "Valmis! CSV salvestatud: $csvPath" -ForegroundColor Green

$tulemus | Format-Table -AutoSize

Import-Module .\Saada-Teavitus.psm1 -Force

foreach ($r in $tulemus) {

    $baite = (Get-Item $r.Tee -ErrorAction SilentlyContinue).Length

    if ($baite -ge 5GB) {
        Send-AlertMessage -Message "Väga suur fail: $($r.Nimi)" -Severity Critical
    }
    elseif ($baite -ge 1GB) {
        Send-AlertMessage -Message "Suur fail: $($r.Nimi)" -Severity Warning
    }
}