<#
.SYNOPSIS
  Serverite saadavuse monitor (Ülesanne B)
#>

[CmdletBinding()]
param(
    [string]$InputFile = "hostid.csv",
    [string]$OutputFolder = "."
)

# UTF-8 täpitähtede tugi konsoolis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-HostStatus {
    param(
        [string]$Name,
        [string]$Hostname,
        [int]$Port,
        [string]$Description
    )

    if ($Port -eq 0) {
        $ping = Test-Connection -ComputerName $Hostname -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $ping
    }
    else {
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect($Hostname, $Port)
            $client.Close()
            return $true
        }
        catch {
            return $false
        }
    }
}

# Loeme hostid CSV-st
$hosts = Import-Csv -Path $InputFile

# Loome väljundkausta kui vaja
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Töötleme hostid
$results = foreach ($h in $hosts) {
    $status = Test-HostStatus `
        -Name $h.nimi `
        -Hostname $h.host `
        -Port $h.port `
        -Description $h.kirjeldus

    [PSCustomObject]@{
        Name        = $h.nimi
        Hostname    = $h.host
        Port        = $h.port
        Description = $h.kirjeldus
        Status      = if ($status) { "OK" } else { "FAIL" }
    }
}

# Salvestame tulemuse CSV-sse
$outFile = Join-Path $OutputFolder "tulemus.csv"
$results | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8

Write-Host "Valmis! Tulemused salvestati: $outFile" -ForegroundColor Green
