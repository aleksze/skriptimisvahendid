# ============================================================
#  Saada-Teavitus.psm1
#  PowerShelli teavituste moodul — saadab teateid Discordi
#  webhook'i kaudu. Power Automate'i puhul muuda Send-DiscordPayload
#  sisu (vaata README.md).
#
#  Autor: NAIDIS (kursuse KIT-24 näidislahendus)
# ============================================================

# Mooduli-tasandi muutujad. $script: scope tähendab, et nad on
# mooduli sees jagatud, aga väljast ei paista.
$script:ConfigPath = Join-Path $PSScriptRoot "config.psd1"
$script:LogPath    = Join-Path $env:TEMP "ps-alerts.log"


function Get-AlertConfig {
<#
.SYNOPSIS
    Loeb mooduli konfiguratsiooni — eelistades keskkonnamuutujat.

.DESCRIPTION
    Otsib webhook-URL-i kahest kohast:
      1. keskkonnamuutujast $env:ALERT_WEBHOOK (soovitatav CI/serveri jaoks)
      2. failist config.psd1 mooduli kõrval (mugav arendamiseks)
    Kui kumbki pole seadistatud, viskab erandi.
#>
    [CmdletBinding()]
    param()

    if ($env:ALERT_WEBHOOK) {
        Write-Verbose "Kasutan webhook URL-i keskkonnamuutujast ALERT_WEBHOOK"
        return @{ WebhookUrl = $env:ALERT_WEBHOOK }
    }

    if (Test-Path $script:ConfigPath) {
        Write-Verbose "Kasutan konfifaili: $script:ConfigPath"
        return Import-PowerShellDataFile $script:ConfigPath
    }

    throw "Teavituse konfiguratsioon puudub. Kas määra ALERT_WEBHOOK keskkonnamuutuja VÕI loo fail config.psd1 (vaata config.example.psd1)."
}


function Write-AlertLog {
<#
.SYNOPSIS
    Sisemine abifunktsioon — kirjutab ühe rea logifaili.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("OK","FAIL")]
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

    # UTF-8 kodeering, et täpitähed ei korrumpeeruks
    Add-Content -Path $script:LogPath -Value $rida -Encoding UTF8
}


function Send-AlertMessage {
<#
.SYNOPSIS
    Saadab teavituse eelseadistatud Discord-kanalisse.

.DESCRIPTION
    Send-AlertMessage saadab HTTP POST-i Discord webhook-URL-ile.
    URL loetakse keskkonnamuutujast $env:ALERT_WEBHOOK või
    konfifailist config.psd1 — MITTE kunagi koodist. Severity
    järgi värvib teate (sinine / kollane / punane).

    Iga saatmine (õnnestunud või ebaõnnestunud) logitakse faili
    $env:TEMP\ps-alerts.log.

    Kui saatmine ebaõnnestub, funktsioon EI VISKA erandit —
    kirjutab hoiatuse ja logib vea. See on teadlik otsus:
    monitooringu skript ei tohi peatuda ainult seepärast, et
    teavituskanal on hetkel maas.

.PARAMETER Message
    Teate sisu. Kohustuslik, ei tohi olla tühi.

.PARAMETER Severity
    Raskusaste: Info, Warning või Critical. Vaikimisi Info.

.PARAMETER Source
    Allika nimi (nt serveri nimi). Vaikimisi käesolev arvuti.

.EXAMPLE
    Send-AlertMessage -Message "Ketas 90% täis" -Severity Warning

.EXAMPLE
    Send-AlertMessage -Message "Teenus maas!" -Severity Critical -Source "DC01"

.EXAMPLE
    # -Verbose näitab detailsemat infot
    Send-AlertMessage -Message "Test" -Verbose

.LINK
    https://discord.com/developers/docs/resources/webhook
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
            throw "Webhook URL pole konfiguratsioonis määratud (vaata config.example.psd1)."
        }

        # Discord embed värv severity järgi (RGB decimal)
        $color = switch ($Severity) {
            "Info"     { 3447003  }   # sinine
            "Warning"  { 16776960 }   # kollane
            "Critical" { 15158332 }   # punane
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

        # Saadame utf-8 baitidena — nii ei kaota täpitähti
        # PowerShell 5.1-l on Invoke-RestMethod -Body stringiga
        # utf-8 tugi kohati katki. Baidid on alati õiged.
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
        # NB: me EI VISKA erandit edasi. Skript peab jätkama.
    }
}


# Avame välja ainult avaliku funktsiooni.
# Get-AlertConfig ja Write-AlertLog jäävad sisemiseks.
Export-ModuleMember -Function Send-AlertMessage
