[CmdletBinding()]
param(
    [string]$Sisend = "hostid.csv",
    [string]$Väljund = ""
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
            $r = Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction Stop
            $v = (Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop).ResponseTime
            return [PSCustomObject]@{
                Olek        = if ($r) { "OK" } else { "FAIL" }
                Viivitus_ms = $v
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

$hostid = Import-Csv -Path $Sisend

Write-Host "Kontrollin $($hostid.Count) hosti..."
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

    $värv = if ($test.Olek -eq "OK") { "Green" } else { "Red" }
    Write-Host ("  {0,-15} {1,-25} {2,-5} {3} ms" -f `
        $h.nimi, $h.host, $test.Olek, $test.Viivitus_ms) `
        -ForegroundColor $värv
}

$kuupäev = Get-Date -Format "yyyy-MM-dd"
if (-not $Väljund) { $Väljund = "saadavus_$kuupäev.csv" }

$tulemus | Export-Csv -Path $Väljund -NoTypeInformation -Encoding UTF8BOM

$ok   = ($tulemus | Where-Object Olek -eq "OK").Count
$fail = ($tulemus | Where-Object Olek -eq "FAIL").Count

Write-Host ""
Write-Host "Kokkuvõte: $ok / $($tulemus.Count) OK, $fail maas" -ForegroundColor Cyan
Write-Host "Tulemus salvestatud: $Väljund" -ForegroundColor Cyan

$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"

if ((Test-Path $moodul) -and $fail -gt 0) {
    Import-Module $moodul -Force
    $maas = ($tulemus | Where-Object Olek -eq "FAIL" | Select-Object -ExpandProperty Nimi) -join ", "
    Send-AlertMessage -Message "Hosti(d) maas: $maas" -Severity Warning -Source "Oleku kontroll"
}