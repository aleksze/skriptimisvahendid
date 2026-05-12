param(
    [Parameter(Position = 0)]
    [string]$Otsingukoht = $HOME,

    [int]$TopN = 10,

    [string[]]$ValistaKaustad = @("AppData"),

    [double]$WarnGB = 1,
    [double]$CritGB = 5,

    [string]$Väljund = "suurimad_failid.csv"
)

$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"
if (Test-Path $moodul) {
    Import-Module $moodul -Force
    $teavitusedLubatud = $true
} else {
    Write-Warning "Saada-Teavitus.psm1 puudub — jätkan ilma teavitusteta."
    $teavitusedLubatud = $false
}

if (-not (Test-Path -Path $Otsingukoht -PathType Container)) {
    Write-Error "Otsingukoht ei ole olemas või ei ole kaust: $Otsingukoht"
    exit 1
}

$valistaRegex = if ($ValistaKaustad.Count -gt 0) {
    '(\\|/)(?:' + (($ValistaKaustad | ForEach-Object { [Regex]::Escape($_) }) -join '|') + ')(\\|/)'
} else {
    $null
}

Write-Host "Otsin $Otsingukoht alt $TopN kõige suuremat faili..." -ForegroundColor Cyan

$failid = Get-ChildItem -Path $Otsingukoht -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not $valistaRegex -or $_.FullName -notmatch $valistaRegex } |
    Sort-Object -Property Length -Descending |
    Select-Object -First $TopN

function Format-Suurus {
    param([long]$Baite)
    if     ($Baite -ge 1GB) { "{0:N1} GB" -f ($Baite / 1GB) }
    elseif ($Baite -ge 1MB) { "{0:N1} MB" -f ($Baite / 1MB) }
    else                    { "{0:N1} KB" -f ($Baite / 1KB) }
}

$tulemus = foreach ($fail in $failid) {
    [PSCustomObject]@{
        Tee      = $fail.FullName
        Nimi     = $fail.Name
        Suurus   = Format-Suurus -Baite $fail.Length
        Baite    = $fail.Length
        Muudetud = $fail.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

$csvPath = Join-Path $PSScriptRoot $Väljund

$tulemus |
    Select-Object Tee, Nimi, Suurus, Muudetud |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "Salvestatud: $csvPath" -ForegroundColor Green

$tulemus | Select-Object Nimi, Suurus, Tee | Format-Table -AutoSize

if ($teavitusedLubatud) {
    $warnBytes = $WarnGB * 1GB
    $critBytes = $CritGB * 1GB

    foreach ($r in $tulemus) {
        if ($r.Baite -ge $critBytes) {
            Send-AlertMessage `
                -Message "Väga suur fail: $($r.Tee) ($($r.Suurus))" `
                -Severity Critical
        }
        elseif ($r.Baite -ge $warnBytes) {
            Send-AlertMessage `
                -Message "Suur fail: $($r.Tee) ($($r.Suurus))" `
                -Severity Warning
        }
    }
}
