<#
.SYNOPSIS
    Kontrollib CSV-failist loetud hostide võrgukättesaadavust.

.DESCRIPTION
    Loeb hostide nimekirja CSV-failist, testib iga hosti TCP- või ICMP-ühendusega,
    kuvab tulemused konsoolis ja salvestab CSV-raportisse.
    Kui Saada-Teavitus.psm1 on olemas ja mõni host on maas, saadetakse teavitus.

.PARAMETER Sisend
    Hostide CSV-faili tee. Vaikimisi: hostid.csv

.PARAMETER Väljund
    CSV-raporti kaust. Vaikimisi: skriptiga sama kaust.
    Failinimi genereeritakse automaatselt: saadavus_<kuupäev>.csv

.EXAMPLE
    .\kontrolli-hostid.ps1

.EXAMPLE
    .\kontrolli-hostid.ps1 -Sisend C:\monitorid\serverid.csv

.NOTES
    Sõltuvus: Saada-Teavitus.psm1 (valikuline — teavituste saatmiseks)
    Kursus:   KIT-24
#>
[CmdletBinding()]
param(
    [string]$Sisend  = (Join-Path $PSScriptRoot "hostid.csv"),
    [string]$Väljund = $PSScriptRoot
)

# ---------------------------------------------------------------------------
# Funktsioon: ühe hosti TCP- või ICMP-test
# ---------------------------------------------------------------------------

function Test-HostStatus {
    <#
    .SYNOPSIS
        Testib ühe hosti kättesaadavust TCP või ICMP kaudu.

    .PARAMETER HostName
        Hosti aadress (IP või domeeninimi).

    .PARAMETER Port
        TCP-port. Kui 0, kasutatakse ICMP pingi.

    .OUTPUTS
        PSCustomObject väljadega Olek (OK/FAIL) ja Viivitus_ms.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostName,
        [int]$Port = 0
    )

    try {
        if ($Port -gt 0) {
            # TCP — kontrollib täpselt seda porti
            $r = Test-NetConnection -ComputerName $HostName -Port $Port `
                                    -WarningAction SilentlyContinue `
                                    -ErrorAction Stop

            return [PSCustomObject]@{
                Olek        = if ($r.TcpTestSucceeded) { "OK" } else { "FAIL" }
                Viivitus_ms = if ($r.PingReplyDetails) { $r.PingReplyDetails.RoundtripTime } else { $null }
            }
        }
        else {
            # ICMP — tavaline ping (port puudub CSV-st)
            $ping = Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop
            return [PSCustomObject]@{
                Olek        = "OK"
                Viivitus_ms = $ping.ResponseTime
            }
        }
    }
    catch {
        # Ühendus ebaõnnestus — tagastame FAIL, mitte ei katkesta skripti
        return [PSCustomObject]@{
            Olek        = "FAIL"
            Viivitus_ms = $null
        }
    }
}

# ---------------------------------------------------------------------------
# Sisend-CSV kontrollimine
# ---------------------------------------------------------------------------

if (-not (Test-Path $Sisend)) {
    Write-Error "Hostide fail ei leitud: $Sisend"
    exit 1
}

$hostid = Import-Csv -Path $Sisend -Encoding UTF8

if (-not $hostid) {
    Write-Warning "Hostide fail on tühi: $Sisend"
    exit 0
}

# ---------------------------------------------------------------------------
# Hostide kontrollimine
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Kontrollin $($hostid.Count) hosti..." -ForegroundColor White
Write-Host ""

$tulemus = foreach ($h in $hostid) {
    $port = if ($h.port -and $h.port -ne "") { [int]$h.port } else { 0 }

    $test = Test-HostStatus -HostName $h.host -Port $port

    # Kuva nimi koos pordiga kui port on määratud
    $hostTekst = if ($port -gt 0) { "$($h.host):$port" } else { $h.host }
    $viivitusTekst = if ($null -ne $test.Viivitus_ms) { "$($test.Viivitus_ms) ms" } else { "-" }

    # Konsooli väljund — joondatud tulpadesse
    $värv = if ($test.Olek -eq "OK") { "Green" } else { "Red" }
    Write-Host ("  {0,-15} {1,-30} {2,-5} {3}" -f `
        $h.nimi, $hostTekst, $test.Olek, $viivitusTekst) -ForegroundColor $värv

    # Tagasta objekt CSV-i jaoks
    [PSCustomObject]@{
        Nimi         = $h.nimi
        Host         = $h.host
        Port         = $h.port
        Olek         = $test.Olek
        Viivitus_ms  = $test.Viivitus_ms
        Kontrollitud = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Kirjeldus    = $h.kirjeldus
    }
}

# ---------------------------------------------------------------------------
# Kokkuvõte konsooli
# ---------------------------------------------------------------------------

$ok   = ($tulemus | Where-Object Olek -eq "OK").Count
$fail = ($tulemus | Where-Object Olek -eq "FAIL").Count

Write-Host ""
Write-Host "Kokkuvõte: $ok / $($tulemus.Count) OK, $fail maas" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# CSV salvestamine (failinimi sisaldab kuupäeva)
# ---------------------------------------------------------------------------

$kuupäev  = Get-Date -Format "yyyy-MM-dd"
$failinimi = Join-Path $Väljund "saadavus_$kuupäev.csv"

$tulemus | Export-Csv -Path $failinimi -NoTypeInformation -Encoding UTF8

Write-Host "Tulemus salvestatud: $failinimi" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Valikuline: teavitus Saada-Teavitus.psm1 kaudu (kui moodul on olemas)
# ---------------------------------------------------------------------------

$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"

if ((Test-Path $moodul) -and $fail -gt 0) {
    Import-Module $moodul -Force
    $maas = ($tulemus | Where-Object Olek -eq "FAIL" | Select-Object -ExpandProperty Nimi) -join ", "
    Send-AlertMessage -Message "Hosti(d) maas: $maas" -Severity Warning -Source "Saadavuse monitor"
    Write-Host "Teavitus saadetud: $maas" -ForegroundColor Yellow
}
