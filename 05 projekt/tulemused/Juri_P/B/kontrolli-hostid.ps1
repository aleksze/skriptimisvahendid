<#
.SYNOPSIS
Kontrollib serverite/hostide saadavust (ICMP või TCP)

.DESCRIPTION
Loeb CSV failist hostid, kontrollib nende kättesaadavust ja salvestab tulemuse CSV faili.

.PARAMETER Sisend
Sisend CSV fail (vaikimisi hostid.csv)

.EXAMPLE
.\kontrolli-hostid.ps1
#>

[CmdletBinding()]
param(
    [string]$Sisend = "hostid.csv"
)

function Test-HostStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [int]$Port = 0
    )

    try {
        if ($Port -gt 0) {
            # TCP kontroll
            $r = Test-NetConnection -ComputerName $ComputerName -Port $Port `
                -WarningAction SilentlyContinue

            return [PSCustomObject]@{
                Olek        = if ($r.TcpTestSucceeded) { "OK" } else { "FAIL" }
                Viivitus_ms = $r.PingReplyDetails.RoundtripTime
            }
        }
        else {
            # ICMP ping
            $ping = Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Stop

            return [PSCustomObject]@{
                Olek        = "OK"
                Viivitus_ms = $ping.ResponseTime
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

# --- Kontroll algab ---

if (!(Test-Path $Sisend)) {
    Write-Error "Sisendfail puudub: $Sisend"
    exit 1
}

$hostid = Import-Csv -Path $Sisend

Write-Host "Kontrollin $($hostid.Count) hosti..." -ForegroundColor Cyan
Write-Host ""

$tulemus = foreach ($h in $hostid) {

    $port = if ($h.port) { [int]$h.port } else { 0 }

    $test = Test-HostStatus -ComputerName $h.host -Port $port

    $obj = [PSCustomObject]@{
        Nimi          = $h.nimi
        Host          = $h.host
        Port          = $h.port
        Olek          = $test.Olek
        Viivitus_ms   = $test.Viivitus_ms
        Kontrollitud  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Kirjeldus     = $h.kirjeldus
    }

    # ilus konsooliväljund
    $varv = if ($test.Olek -eq "OK") { "Green" } else { "Red" }

    $hostDisplay = if ($port -gt 0) { "$($h.host):$port" } else { $h.host }

    Write-Host ("  {0,-15} {1,-25} {2,-5} {3} ms" -f `
        $h.nimi, $hostDisplay, $test.Olek, $test.Viivitus_ms) `
        -ForegroundColor $varv

    $obj
}

# --- Kokkuvõte ---

$ok   = ($tulemus | Where-Object Olek -eq "OK").Count
$fail = ($tulemus | Where-Object Olek -eq "FAIL").Count

$kuupaev = Get-Date -Format "yyyy-MM-dd"
$failinimi = "saadavus_$kuupaev.csv"

$tulemus | Export-Csv -Path $failinimi -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Kokkuvõte: $ok / $($tulemus.Count) OK, $fail maas" -ForegroundColor Cyan
Write-Host "Tulemus salvestatud: $failinimi" -ForegroundColor Cyan