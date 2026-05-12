<#
.SYNOPSIS
PowerShelli teavituste moodul (Discord webhook)

.DESCRIPTION
Saadab teavitusi Discordi webhooki kaudu.
Toetab keskkonnamuutujat ALERT_WEBHOOK ja config.psd1 faili.

Logib kõik sündmused %TEMP%\ps-alerts.log faili.
#>

function Send-AlertMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [string]$Source = $env:COMPUTERNAME
    )

    # --- leia webhook URL ---
    $url = $env:ALERT_WEBHOOK

    if (-not $url) {
        $moduleDir = if ($PSScriptRoot) {
            $PSScriptRoot
        } else {
            Split-Path -Parent $MyInvocation.MyCommand.Path
        }

        $configPath = Join-Path $moduleDir "config.psd1"

        if (Test-Path $configPath) {
            try {
                $cfg = Import-PowerShellDataFile -Path $configPath
                if ($cfg.WebhookUrl) {
                    $url = $cfg.WebhookUrl
                }
            }
            catch {
                Write-Verbose "Config lugemine ebaõnnestus: $($_.Exception.Message)"
            }
        }
    }

    if (-not $url) {
        Write-Warning "Webhook URL puudub (ALERT_WEBHOOK või config.psd1)"
        return
    }

    # --- värv severity järgi ---
    $color = switch ($Severity) {
        "Info"     { 3447003 }
        "Warning"  { 16776960 }
        "Critical" { 15158332 }
    }

    # --- payload ---
    $payload = @{
        username = "PS-Monitor"
        embeds   = @(
            @{
                title       = "[$Severity] $Source"
                description = $Message
                color       = $color
                timestamp   = (Get-Date).ToUniversalTime().ToString("o")
            }
        )
    } | ConvertTo-Json -Depth 4

    # UTF-8 kindel saatmine
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

    $logPath = Join-Path $env:TEMP "ps-alerts.log"
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        Invoke-RestMethod -Uri $url `
            -Method Post `
            -Body $bytes `
            -ContentType "application/json; charset=utf-8" `
            -ErrorAction Stop | Out-Null

        Add-Content -Path $logPath -Value "$time [OK] $Severity | $Source | $Message"
        Write-Verbose "Teavitus saadetud"
    }
    catch {
        Add-Content -Path $logPath -Value "$time [FAIL] $Severity | $Source | $Message | $($_.Exception.Message)"
        Write-Warning "Teavituse saatmine ebaõnnestus: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Send-AlertMessage