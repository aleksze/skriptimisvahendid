function Send-AlertMessage {
<#
.SYNOPSIS
    Saadab teavituse eelmääratud Discordi kanalisse.

.DESCRIPTION
    Send-AlertMessage saadab REST API kaudu teate Discordi webhooki abil.
    Webhooki URL loetakse failist config.psd1, mitte koodist.

.PARAMETER Message
    Teate tekst. Kohustuslik parameeter.

.PARAMETER Severity
    Teate raskusaste: Info, Warning või Critical.
    Vaikimisi võetakse config.psd1 failist.

.PARAMETER Source
    Allika nimi, näiteks serveri või arvuti nimi.
    Vaikimisi kasutatakse kohaliku arvuti nime.

.EXAMPLE
    Send-AlertMessage -Message "Serveriketas 90% täis" -Severity Warning

.EXAMPLE
    Send-AlertMessage -Message "Kriitiline fail kustutatud" -Severity Critical -Source "DC01"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warning", "Critical")]
        [string]$Severity,

        [string]$Source = $env:COMPUTERNAME
    )

    $configPath = Join-Path $PSScriptRoot "config.psd1"
    $config = Import-PowerShellDataFile $configPath

    $url = $config.WebhookUrl
    if (-not $url) {
        throw "WebhookUrl puudub failist config.psd1"
    }

    if (-not $Severity) {
        $Severity = $config.DefaultSeverity
    }

    $color = switch ($Severity) {
        "Info"     { 3447003 }
        "Warning"  { 16776960 }
        "Critical" { 15158332 }
    }

    $payload = @{
        username = "PS-Monitor"
        embeds   = @(
            @{
                title       = "[$Severity] $Source"
                description = $Message
                color       = $color
                timestamp   = (Get-Date).ToString("o")
            }
        )
    } | ConvertTo-Json -Depth 4

    $logPath = Join-Path $env:TEMP "ps-alerts.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
        Write-Host "Teavitus saadetud: $Message"
        Add-Content -Path $logPath -Value "$timestamp [OK] $Severity $Source $Message"
    }
    catch {
        Write-Warning "Teavituse saatmine ebaõnnestus: $($_.Exception.Message)"
        Add-Content -Path $logPath -Value "$timestamp [FAIL] $Severity $Source $Message | $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Send-AlertMessage