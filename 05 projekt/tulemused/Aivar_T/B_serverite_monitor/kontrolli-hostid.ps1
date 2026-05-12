<#
.SYNOPSIS
Kontrollib hostide nimekirja CSV-failist.

.DESCRIPTION
Loeb hostid CSV-failist ja kontrollib, kas määratud host ja port on kättesaadavad.
Salvestab tulemused CSV-faili ja kuvab kokkuvõtte konsoolis.

.PARAMETER SisendCsv
Sisendfaili tee. Kui parameetrit ei anta, kasutatakse hostid.csv faili skripti kaustast.

.PARAMETER ValjundCsv
Väljundfaili tee. Kui parameetrit ei anta, luuakse skripti kausta fail kujul saadavus_YYYY-MM-DD.csv.
#>

[CmdletBinding()]
param(
    [string]$SisendCsv,
    [string]$ValjundCsv
)

function Test-HostStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Nimi,

        [Parameter(Mandatory)]
        [string]$HostName,

        [int]$Port = 0,

        [string]$Kirjeldus
    )

    $kontrollitud = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        if ($Port -gt 0) {
            $r = Test-NetConnection -ComputerName $HostName -Port $Port -WarningAction SilentlyContinue -ErrorAction Stop

            $olek = if ($r.TcpTestSucceeded) { "OK" } else { "FAIL" }
            $viivitus = $null

            if ($null -ne $r.PingReplyDetails) {
                $viivitus = $r.PingReplyDetails.RoundtripTime
            }
        }
        else {
            $r = Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop
            $olek = "OK"
            $viivitus = $r[0].ResponseTime
        }
    }
    catch {
        $olek = "FAIL"
        $viivitus = $null
    }

    [PSCustomObject]@{
        Nimi         = $Nimi
        Host         = $HostName
        Port         = $Port
        Olek         = $olek
        Viivitus_ms  = $viivitus
        Kontrollitud = $kontrollitud
        Kirjeldus    = $Kirjeldus
    }
}

if ([string]::IsNullOrWhiteSpace($SisendCsv)) {
    $skriptiKaust = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SisendCsv = Join-Path $skriptiKaust "hostid.csv"
}

if ([string]::IsNullOrWhiteSpace($ValjundCsv)) {
    $skriptiKaust = Split-Path -Parent $MyInvocation.MyCommand.Path
    $kuupaev = Get-Date -Format "yyyy-MM-dd"
    $ValjundCsv = Join-Path $skriptiKaust "saadavus_$kuupaev.csv"
}

if (-not (Test-Path $SisendCsv)) {
    throw "Sisendfaili ei leitud: $SisendCsv"
}

$hostid = Import-Csv -Path $SisendCsv

Write-Host "Kontrollin $($hostid.Count) hosti..." -ForegroundColor Cyan

$tulemused = foreach ($rida in $hostid) {
    $port = 0
    if (-not [string]::IsNullOrWhiteSpace($rida.port)) {
        $port = [int]$rida.port
    }

    Test-HostStatus -Nimi $rida.nimi -HostName $rida.host -Port $port -Kirjeldus $rida.kirjeldus
}

foreach ($t in $tulemused) {
    $viivitusTekst = if ($null -ne $t.Viivitus_ms) { "$($t.Viivitus_ms) ms" } else { "-" }
    $hostTekst = if ($t.Port -gt 0) { "$($t.Host):$($t.Port)" } else { $t.Host }

    Write-Host ("  {0,-14} {1,-28} {2,-5} {3}" -f $t.Nimi, $hostTekst, $t.Olek, $viivitusTekst)
}

$tulemused | Export-Csv -Path $ValjundCsv -NoTypeInformation -Encoding UTF8

$ok = ($tulemused | Where-Object { $_.Olek -eq "OK" }).Count
$fail = ($tulemused | Where-Object { $_.Olek -eq "FAIL" }).Count

Write-Host ""
Write-Host "Kokkuvõte: $ok / $($tulemused.Count) OK, $fail maas"
Write-Host "Tulemus salvestatud: $ValjundCsv"