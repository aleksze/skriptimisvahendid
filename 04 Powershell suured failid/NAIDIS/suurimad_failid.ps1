# ============================================================
#  suurimad_failid.ps1
#
#  Leiab 10 kõige suuremat faili kodukaustas, salvestab CSV-i JA
#  saadab teavituse kanalisse, kui mõni fail on üle piirmäära.
#
#  Kasutamine:
#    .\suurimad_failid.ps1                              # kodukaust
#    .\suurimad_failid.ps1 -Path C:\Users -TopN 20
#    .\suurimad_failid.ps1 -WarnGB 2 -CritGB 10
# ============================================================

[CmdletBinding()]
param(
    [string]$Path    = $HOME,
    [int]   $TopN    = 10,
    [double]$WarnGB  = 1,
    [double]$CritGB  = 5,
    [string]$Väljund = "suurimad_failid.csv"
)

# --- lae teavituste moodul ---------------------------------------
$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"
if (Test-Path $moodul) {
    Import-Module $moodul -Force
    $teavitusedLubatud = $true
} else {
    Write-Warning "Saada-Teavitus.psm1 puudub — jätkan ilma teavitusteta."
    $teavitusedLubatud = $false
}

# --- abifunktsioon: baidid → loetav --------------------------------
function Format-Suurus {
    param([long]$Baite)
    if     ($Baite -ge 1GB) { "{0:N1} GB" -f ($Baite / 1GB) }
    elseif ($Baite -ge 1MB) { "{0:N1} MB" -f ($Baite / 1MB) }
    else                    { "{0:N1} KB" -f ($Baite / 1KB) }
}

# --- leia failid --------------------------------------------------
Write-Host "Otsin $Path alt $TopN kõige suuremat faili..." -ForegroundColor Cyan

$failid = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
          Sort-Object -Property Length -Descending |
          Select-Object -First $TopN

# --- ehita tulemus --------------------------------------------------
$tulemus = foreach ($fail in $failid) {
    [PSCustomObject]@{
        Tee    = $fail.FullName
        Nimi   = $fail.Name
        Suurus = Format-Suurus -Baite $fail.Length
        Baite  = $fail.Length     # jätame baidid alles võrdluste jaoks
    }
}

# --- salvesta CSV (jätame Baite veeru välja) ------------------------
$tulemus |
    Select-Object Tee, Nimi, Suurus |
    Export-Csv -Path $Väljund -NoTypeInformation -Encoding UTF8

Write-Host "Salvestatud: $Väljund" -ForegroundColor Green

# --- ekraanile --------------------------------------------------------
$tulemus | Select-Object Nimi, Suurus, Tee | Format-Table -AutoSize

# --- saada teavitused piirmäärade alusel ---------------------------
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
