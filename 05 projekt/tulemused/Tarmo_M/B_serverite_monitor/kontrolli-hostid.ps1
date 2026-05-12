<#
.SYNOPSIS
    Kontrollib nimekirja hostide saadavust ja salvestab tulemused CSV-faili.

.DESCRIPTION
    Loeb hostide nimekirja CSV-failist ning kontrollib iga hosti kättesaadavust:
      - kui real on määratud port, kasutatakse Test-NetConnection (TCP)
      - muidu kasutatakse Test-Connection (ICMP ping)
    Tulemused salvestatakse CSV-i kujul saadavus_<kuupäev>.csv.

.PARAMETER InputCsv
    Sisend-CSV failinimi (vaikimisi hostid.csv skripti kaustas).

.PARAMETER OutputDir
    Kaust, kuhu väljund-CSV salvestatakse (vaikimisi skripti kaust).

.EXAMPLE
    .\kontrolli-hostid.ps1

.NOTES
    Autor: Tarmo M
    Kursus: KIT-24
#>

[CmdletBinding()]
param(
    [string]$InputCsv  = (Join-Path $PSScriptRoot "hostid.csv"),
    [string]$OutputDir = $PSScriptRoot
)

function Test-HostStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostName,
        [int]$Port = 0
    )

    try {
        if ($Port -gt 0) {
            $r = Test-NetConnection -ComputerName $HostName -Port $Port `
                                    -WarningAction SilentlyContinue -ErrorAction Stop
            $latency = $null
            if ($r.PingReplyDetails) { $latency = $r.PingReplyDetails.RoundtripTime }

            return [PSCustomObject]@{
                Olek        = if ($r.TcpTestSucceeded) { "OK" } else { "FAIL" }
                Viivitus_ms = $latency
            }
        }
        else {
            $ok  = Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction Stop
            $rtt = $null
            if ($ok) {
                $ping = Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop
                $rtt  = $ping.ResponseTime
            }
            return [PSCustomObject]@{
                Olek        = if ($ok) { "OK" } else { "FAIL" }
                Viivitus_ms = $rtt
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Olek        = "FAIL"
            Viivitus_ms = $null
        }
    }
}

if (-not (Test-Path $InputCsv)) {
    Write-Error "Sisend-CSV ei leitud: $InputCsv"
    exit 1
}

$hostid = Import-Csv -Path $InputCsv
Write-Host ""
Write-Host "Kontrollin $($hostid.Count) hosti..." -ForegroundColor Yellow
Write-Host ""

$tulemus = foreach ($h in $hostid) {
    $port = 0
    if ($h.port -and [int]::TryParse($h.port, [ref]$port)) { $port = [int]$h.port }

    $test = Test-HostStatus -HostName $h.host -Port $port

    $rida = [PSCustomObject]@{
        Nimi          = $h.nimi
        Host          = $h.host
        Port          = $h.port
        Olek          = $test.Olek
        Viivitus_ms   = $test.Viivitus_ms
        Kontrollitud  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Kirjeldus     = $h.kirjeldus
    }

    $hostKuva = if ($port -gt 0) { "$($h.host):$port" } else { $h.host }
    $viiv     = if ($null -ne $test.Viivitus_ms) { "$($test.Viivitus_ms) ms" } else { "-" }
    $värv     = if ($test.Olek -eq "OK") { "Green" } else { "Red" }

    Write-Host ("  {0,-15} {1,-28} {2,-5} {3}" -f `
        $h.nimi, $hostKuva, $test.Olek, $viiv) -ForegroundColor $värv

    $rida
}

$kuupäev   = Get-Date -Format "yyyy-MM-dd"
$failinimi = Join-Path $OutputDir "saadavus_$kuupäev.csv"

$tulemus | Export-Csv -Path $failinimi -NoTypeInformation -Encoding UTF8

$ok   = ($tulemus | Where-Object Olek -eq "OK").Count
$fail = ($tulemus | Where-Object Olek -eq "FAIL").Count

Write-Host ""
Write-Host "Kokkuvõte: $ok / $($tulemus.Count) OK, $fail maas" -ForegroundColor Cyan
Write-Host "Tulemus salvestatud: $failinimi" -ForegroundColor Cyan

$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"
if ((Test-Path $moodul) -and $fail -gt 0) {
    try {
        Import-Module $moodul -Force
        $maas = ($tulemus | Where-Object Olek -eq "FAIL" | Select-Object -ExpandProperty Nimi) -join ", "
        Send-AlertMessage -Message "Hosti(d) maas: $maas" -Severity Warning -Source "Saadavuse monitor"
    }
    catch {
        Write-Warning "Teavituse saatmine ebaõnnestus: $($_.Exception.Message)"
    }
}
