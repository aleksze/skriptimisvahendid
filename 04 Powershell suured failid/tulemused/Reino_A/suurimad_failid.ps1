param(
    [string]$OtsinguKaust = $HOME
)

$failid = Get-ChildItem -Path $OtsinguKaust -Recurse -File -ErrorAction SilentlyContinue |
Where-Object { 
	$_.FullName -notlike "*Documents\Outlook Files*" -and #Jäta välja, mille täistee sisaldab Documents\Outlook Files
	$_.FullName -notlike "*\AppData\*" #Jäta välja AppData
} 

$top = $failid |
    Sort-Object -Property Length -Descending |
    Select-Object -First 10

$tulemus = foreach ($fail in $top) {

    $baite = $fail.Length

    if ($baite -ge 1GB) {
        $suurus = "{0:N1} GB" -f ($baite / 1GB)
    } elseif ($baite -ge 1MB) {
        $suurus = "{0:N1} MB" -f ($baite / 1MB)
    } else {
        $suurus = "{0:N1} KB" -f ($baite / 1KB)
    }

    [PSCustomObject]@{
        Tee    = $fail.FullName
        Nimi   = $fail.Name
        Suurus = $suurus
	Muudetud = $fail.LastWriteTime
    }
}

$tulemus | Export-Csv -Path ".\suurimad_failid.csv" -NoTypeInformation -Encoding UTF8
