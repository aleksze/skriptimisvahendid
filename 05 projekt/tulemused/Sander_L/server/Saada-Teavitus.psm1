function  Send-AlertMessage {
    <#
    .SYNOPSIS
    Saadab teavituse eelseadistatud kanalisse (Discord / Teams).

    .DESCRIPTION
    Send-AlertMessage saadab REST API kaudu teate monitooringu­kanalisse.
    URL loetakse keskkonnamuutujast või konfifailist, mitte koodist.

    .PARAMETER Message
    Teate tekst. Kohustuslik.

    .PARAMETER Severity
    Teate raskusaste: Info, Warning või Critical. Vaikimisi Info.

    .PARAMETER Source
    Allika nimi (nt serveri nimi). Vaikimisi käesoleva arvuti nimi.

    .EXAMPLE
    Send-AlertMessage -Message "Ketas 90% täis" -Severity Warning

    .EXAMPLE
    Send-AlertMessage -Message "Teenus maas" -Severity Critical -Source "DC01"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [string]$Source = $env:COMPUTERNAME
    )

    $color = switch ($Severity) {
        "Info" { 3447003 }  #sinine
        "Warning" { 16776960 } #kollane
        "Critical" { 15158332 } # punane
    }

    $payload = @{
        username = "PS-Monitor"
        embeds = @(@{
            title = "[$Severity] $Source"
            description = $Message
            color = $color
            timestamp = (Get-Date).ToString("o")
        })
    } | ConvertTo-Json -Depth 4

    $url = $env:ALERT_WEBHOOK
    if (-not $url) { throw "ALERT_WEBHOOK keskkonnamuutuja puudub" }

    $logPath = Join-Path $env:TEMP "ps-alerts.log"
    $aeg = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
        Add-Content -Path $logPath -Value "$aeg [OK] $Severity | $Source | $Message"
        Write-Verbose "Teavitus saadetud: $Message"
    }
    catch {
        Add-Content -Path $logPath -Value "$aeg [FAIL] $Severity | $Source | $Message | $($_.Exception.Message)"
        Write-Warning "Teavituse saatmine ebaõnnestust: $($_.Exception.Message)"
    }

    
}

Export-ModuleMember -Function Send-AlertMessage
