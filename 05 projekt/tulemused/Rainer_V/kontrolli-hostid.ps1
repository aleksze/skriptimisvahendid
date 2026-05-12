<#
.SYNOPSIS
    Kontrollib hostide saadavust ja salvestab tulemuse CSV-i.

.DESCRIPTION
    Loeb hostide nimekirja CSV-st, kontrollib igaüht (TCP port või ICMP ping)
    ja salvestab tulemuse kuupäevaga CSV-faili.

.PARAMETER Sisend
    Hostide CSV-fail (vaikimisi hostid.csv)

.EXAMPLE
    .\kontrolli-hostid.ps1

.EXAMPLE
    .\kontrolli-hostid.ps1 -Sisend "minu_hostid.csv"
#>

[CmdletBinding()]
param(
    [string]$Sisend = "hostid.csv"
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
            return [PSCustomObject]@{
                Olek        = if ($r.TcpTestSucceeded) { "OK" } else { "FAIL" }
                Viivitus_ms = $r.PingReplyDetails.RoundtripTime
            }
        }
        else {
            $r = Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop
            return [PSCustomObject]@{
                Olek        = "OK"
                Viivitus_ms = $r.ResponseTime
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

$csvPath = Join-Path $PSScriptRoot $Sisend
if (-not (Test-Path $csvPath)) {
    Write-Error "Sisendfail puudub: $csvPath"
    exit 1
}

$hostid = Import-Csv -Path $csvPath

Write-Host "Kontrollin $($hostid.Count) hosti..." -ForegroundColor Cyan
Write-Host ""

$tulemus = foreach ($h in $hostid) {
    $port = if ($h.port) { [int]$h.port } else { 0 }
    $test = Test-HostStatus -HostName $h.host -Port $port

    [PSCustomObject]@{
        Nimi         = $h.nimi
        Host         = $h.host
        Port         = $h.port
        Olek         = $test.Olek
        Viivitus_ms  = $test.Viivitus_ms
        Kontrollitud = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Kirjeldus    = $h.kirjeldus
    }

    $varv = if ($test.Olek -eq "OK") { "Green" } else { "Red" }
    $viivitus = if ($test.Viivitus_ms) { "$($test.Viivitus_ms) ms" } else { "-" }
    Write-Host ("  {0,-15} {1,-30} {2,-5} {3}" -f $h.nimi, $h.host, $test.Olek, $viivitus) -ForegroundColor $varv
}

$kuupaev = Get-Date -Format "yyyy-MM-dd"
$failinimi = Join-Path $PSScriptRoot "saadavus_$kuupaev.csv"

$tulemus | Export-Csv -Path $failinimi -NoTypeInformation -Encoding UTF8

$ok   = ($tulemus | Where-Object Olek -eq "OK").Count
$fail = ($tulemus | Where-Object Olek -eq "FAIL").Count

Write-Host ""
Write-Host "Kokkuvõte: $ok / $($tulemus.Count) OK, $fail maas" -ForegroundColor Cyan
Write-Host "Tulemus salvestatud: $failinimi" -ForegroundColor Cyan
