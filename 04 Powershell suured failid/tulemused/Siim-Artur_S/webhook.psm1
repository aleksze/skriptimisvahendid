function Send-AlertMessage {
    param (
        [string]$Message,
        [string]$Severity = "Info",
        [string]$Source = "Monitor"
    )
    
    $configPath = Join-Path $PSScriptRoot "config.psd1"
    
    if (-not (Test-Path $configPath)) {
        Write-Error "Config puudub: $configPath"
        return
    }
    
    $config = Import-PowerShellDataFile $configPath
    $url = $config.WebhookUrl  # <-- config.psd1-s peab olema WebhookUrl = "https://..."

    if ([string]::IsNullOrEmpty($url)) {
        Write-Error "WebhookUrl on config.psd1-s tühi või puudub!"
        return
    }

    $payload = @{
        content = "[$Severity] $Source`n$Message"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json"
}

Export-ModuleMember -Function Send-AlertMessage