$script:ConfigPath = Join-Path $PSScriptRoot "config.psd1"
$script:LogPath    = Join-Path $env:TEMP "ps-alerts.log"


function Get-AlertConfig {
    [CmdletBinding()]
    param()

    if ($env:ALERT_WEBHOOK) {
        Write-Verbose "Webhook URL loetud keskkonnamuutujast"
        return @{ WebhookUrl = $env:ALERT_WEBHOOK }
    }

    if (Test-Path $script:ConfigPath) {
        Write-Verbose "Webhook URL loetud failist: $script:ConfigPath"
        return Import-PowerShellDataFile $script:ConfigPath
    }

    throw "Webhook URL puudub! Määra ALERT_WEBHOOK keskkonnamuutuja või loo config.psd1 (vaata config.example.psd1)."
}


function Write-AlertLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("OK","FAIL")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$ErrorText
    )

    $aeg  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $rida = "$aeg [$Status]`t$Severity`t$Source`t$Message"
    if ($ErrorText) { $rida += "`t$ErrorText" }

    Add-Content -Path $script:LogPath -Value $rida -Encoding UTF8
}


function Send-AlertMessage {
<#
.SYNOPSIS
    Saadab teavituse Discord-kanalisse webhook kaudu.

.DESCRIPTION
    Send-AlertMessage saadab HTTP POST päringu Discord webhook URL-ile.
    URL loetakse keskkonnamuutujast ALERT_WEBHOOK või konfifailist config.psd1.
    Teate värv sõltub Severity tasemest.

    Iga saatmiskatse logitakse faili %TEMP%\ps-alerts.log.
    Kui saatmine ebaõnnestub, skript jätkab tööd.

.PARAMETER Message
    Teate sisu tekst. Kohustuslik.

.PARAMETER Severity
    Raskusaste: Info, Warning või Critical. Vaikimisi Info.

.PARAMETER Source
    Allika nimi (nt serveri nimi). Vaikimisi arvuti nimi.

.EXAMPLE
    Send-AlertMessage -Message "Ketas 90% täis" -Severity Warning

.EXAMPLE
    Send-AlertMessage -Message "Teenus maas!" -Severity Critical -Source "DC01"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [string]$Source = $env:COMPUTERNAME
    )

    try {
        $config = Get-AlertConfig
        $url    = $config.WebhookUrl

        if (-not $url -or $url -match "PANE_SIIA") {
            throw "Webhook URL pole seadistatud (vaata config.example.psd1)."
        }

        $color = switch ($Severity) {
            "Info"     { 3447003  }
            "Warning"  { 16776960 }
            "Critical" { 15158332 }
        }

        $payload = @{
            username = "PS-Monitor"
            embeds   = @(@{
                title       = "[$Severity] $Source"
                description = $Message
                color       = $color
                timestamp   = (Get-Date).ToUniversalTime().ToString("o")
            })
        } | ConvertTo-Json -Depth 4

        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

        Invoke-RestMethod -Uri $url `
                          -Method Post `
                          -Body $bytes `
                          -ContentType "application/json; charset=utf-8" `
                          -ErrorAction Stop | Out-Null

        Write-AlertLog -Status OK -Severity $Severity -Source $Source -Message $Message
        Write-Verbose "Teavitus saadetud: [$Severity] $Message"
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-AlertLog -Status FAIL -Severity $Severity -Source $Source `
                       -Message $Message -ErrorText $errMsg
        Write-Warning "Teavituse saatmine ebaõnnestus: $errMsg"
    }
}


Export-ModuleMember -Function Send-AlertMessage
