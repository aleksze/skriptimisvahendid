# Teavituste moodul — näidislahendus

**Kursus:** KIT-24
**Autor:** NAIDIS

PowerShelli moodul, mis saadab teavitusi Discord-webhook'i kaudu.
Harjutuse „PowerShelli teavituste moodul REST API kaudu“ näidislahendus.

---

## Failid

| Fail | Kirjeldus | Gitis? |
|---|---|:---:|
| `Saada-Teavitus.psm1` | Moodul koos funktsiooniga `Send-AlertMessage` | ✅ |
| `config.example.psd1` | Näidiskonfig — tühja URL-iga | ✅ |
| `config.psd1` | Päris konfig koos webhook URL-iga | ❌ |
| `suurimad_failid.ps1` | Integreeritud skript — leiab suured failid ja teavitab | ✅ |
| `.gitignore` | Peidab `config.psd1` ja `*.log` | ✅ |
| `%TEMP%\ps-alerts.log` | Automaatselt tekkiv logifail | ❌ |

---

## Paigaldamine

```powershell
# 1. Kopeeri näidiskonfig ja täida URL
Copy-Item config.example.psd1 config.psd1
notepad config.psd1          # pane WebhookUrl väärtuseks päris URL

# 2. Veendu, et saladus on peidus
git status                   # config.psd1 EI TOHI nimekirjas olla

# 3. Testi
Import-Module .\Saada-Teavitus.psm1 -Force
Send-AlertMessage -Message "Paigaldus õnnestus" -Severity Info
```

Alternatiiv — kui eelistad keskkonnamuutujat (turvalisem serveris):

```powershell
[Environment]::SetEnvironmentVariable("ALERT_WEBHOOK", "https://discord.com/api/webhooks/...", "User")
# Käivita PowerShell uuesti, et muutuja laetaks
```

Kui mõlemad on olemas, võidab keskkonnamuutuja.

---

## Kasutamine

### Põhiline

```powershell
Import-Module .\Saada-Teavitus.psm1

Send-AlertMessage -Message "Server käivitus"                                  # Info
Send-AlertMessage -Message "Ketas 87% täis" -Severity Warning
Send-AlertMessage -Message "Teenus maas!"  -Severity Critical -Source "DC01"
```

### Pipeline'ist

```powershell
Get-Service | Where-Object Status -eq Stopped |
    ForEach-Object {
        Send-AlertMessage -Message "Teenus seiskunud: $($_.Name)" -Severity Warning
    }
```

### Abiinfo

```powershell
Get-Help Send-AlertMessage -Full
Get-Help Send-AlertMessage -Examples
```

### Integreeritud skript

```powershell
.\suurimad_failid.ps1                                 # kodukaust, 10 faili
.\suurimad_failid.ps1 -Path C:\Users -TopN 20         # mujalt, rohkem
.\suurimad_failid.ps1 -WarnGB 0.5 -CritGB 2           # madalamad piirid
```

---

## Logifail

Iga saatmine logitakse `%TEMP%\ps-alerts.log` faili, tabulaatoriga eraldatud veergudes:

```
2026-04-20 14:22:01 [OK]    Info      DESKTOP-42   Paigaldus õnnestus
2026-04-20 14:22:05 [OK]    Warning   DESKTOP-42   Suur fail: C:\Users\...\backup.zip (2.3 GB)
2026-04-20 14:22:07 [FAIL]  Critical  DESKTOP-42   Test    The remote name could not be resolved
```

Logi vaatamiseks:

```powershell
Get-Content "$env:TEMP\ps-alerts.log" -Tail 20
```

---

## Kohandamine — Power Automate'i jaoks

Kui soovid kasutada Discordi asemel Microsoft Teams-i läbi Power Automate'i, muuda mooduli `Send-AlertMessage` funktsiooni `$payload` osa nii, et väljad vastaksid sinu Flow'i HTTP-trigeri skeemile:

```powershell
$payload = @{
    message  = $Message
    severity = $Severity
    source   = $Source
} | ConvertTo-Json
```

Ja `config.psd1` `WebhookUrl` paneb Power Automate'i HTTP POST URL-i. Kõik muu (logimine, veakäsitlus, parameetrid) toimib samamoodi.

---

## Hea tava — checklist

Iga „Hea tava“ punkt harjutuses:

- [x] **Verb-Noun nimi** — `Send-AlertMessage` (`Send` on `Get-Verb` lubatud)
- [x] **`[CmdletBinding()]`** — kõigil funktsioonidel
- [x] **`param()` blokk** — ei mingit `$args`
- [x] **`[Parameter(Mandatory)]`** — `-Message` kohustuslik
- [x] **`[ValidateSet(...)]`** — `-Severity` lubab ainult Info/Warning/Critical
- [x] **Saladusi pole koodis** — URL loetakse konfist või env-muutujast
- [x] **`.gitignore`** — sisaldab `config.psd1` ja `*.log`
- [x] **`try/catch`** — `Invoke-RestMethod` ümber, skript ei jookse kokku
- [x] **Kommentaaripõhine abi** — `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE` jne
- [x] **Logimine** — iga saatmine faili koos ajatempliga
- [x] **Väljumise kood** — teadlik otsus: viga ei katkesta monitooringut, ainult logitakse

---

## Teadaolevad piirangud

- Discordil on rate limit ~30 päringut minutis ühe webhooki kohta. Massiliste teavituste puhul tuleks lisada debouncing (vaata harjutuse lisaküsimust #2).
- Logifail ei rotateeru automaatselt. Pikaaegses kasutuses lisada logide rotatsioon (`Rotate-Log` funktsioon või `Scheduled Task`).
- PS 5.1-l kohati probleeme täpitähtedega — mooduli kood kasutab UTF-8 baite, mis lahendab probleemi.
