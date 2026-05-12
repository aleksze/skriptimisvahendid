$releasePage = Invoke-WebRequest "https://installer.id.ee/media/win/" -UseBasicParsing

$latestLink = $releasePage.Links |
    Where-Object { $_.href -match '^Open-EID-(\d+(?:\.\d+){3})\.exe$' } |
    Select-Object -ExpandProperty href |
    Sort-Object { [Version]($_ -replace '^Open-EID-|\.exe$','') } |
    Select-Object -Last 1

$latestVersionString = $latestLink -replace '^Open-EID-|\.exe$',''
$latestVersion = [Version]$latestVersionString

$localApp = Get-ItemProperty `
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", `
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq "eID software" } |
    Select-Object -First 1

$localVersionString = $localApp.DisplayVersion
$localVersion = [Version]$localVersionString

Write-Host "Veebis uusim versioon: $latestVersionString"
Write-Host "Arvutis paigaldatud versioon: $localVersionString"

if ($latestVersion -gt $localVersion) {
    Write-Host "Uuem ID-tarkvara versioon on saadaval."

    Import-Module "C:\Users\tahka\skriptimisvahendid\04 Powershell suured failid\tulemused\Aivar_T\Saada-Teavitus.psm1" -Force

    Send-AlertMessage -Message "ID-tarkvara uus versioon on saadaval: $latestVersionString. Arvutis on praegu: $localVersionString." -Severity Warning -Source $env:COMPUTERNAME
}
else {
    Write-Host "ID-tarkvara on ajakohane."
}