# Harjutus: PowerShelli teavituste moodul REST API kaudu

**Kursus:** KIT-24
**Õpetaja:** Toivo Pärnpuu
**Keel:** PowerShell
**Moodul:** `Microsoft.PowerShell.Utility` (tuleb PowerShelliga kaasa)
NB! Lisa oma lahendus samasse kausta kus eelmine töö.
---

## Eesmärk

Eelmises harjutuses leidsid kettalt 10 kõige suuremat faili. Päris IT-administraator ei loe aga iga hommik CSV-faili — ta tahab, et **skript ise annaks märku**, kui midagi on valesti. Selles harjutuses ehitad PowerShelli mooduli, mis saadab teateid REST API kaudu välisesse kanalisse (Discord või Microsoft Teams), ja lisad selle oma eelmisele skriptile.

Õpid, kuidas:

- saata HTTP-päringuid PowerShellist (`Invoke-RestMethod`)
- pakendada taaskasutatav kood **mooduliks** (`.psm1`)
- kirjutada funktsioone, mis järgivad PowerShelli häid tavasid
- hoida saladusi (API-võtmeid, webhook-URL-e) **mitte** Gitis
- ühendada kaks skripti üheks töövooks

---

## Stsenaarium

Oled firma süsteemiadministraator. Serverite kõvakettad saavad liiga tihti täis ja keegi ei märka seda enne, kui midagi kokku jookseb. Sinu ülesanne: kirjuta tööriist, mis **avastab probleemi** ja **saadab kohe teate** meeskonna kanalisse.

---

## Valikud — kumba kanalit kasutad?

Valid ise, kumma teed. Mõlemad töötavad sama põhimõttega: sa saadad HTTP POST päringu URL-ile, teine pool paneb teate kanalisse.

| Kanal | Plussid | Miinused |
|---|---|---|
| **Discord webhook** | Tasuta, 2 minutit seadistada, ei vaja kontorilitsentsi | Ei ole "ettevõtte" kanal |
| **Power Automate → Teams** | Realistlik ettevõttelahendus, integreerub M365-ga | Nõuab Techno-TLN kontot ja natuke rohkem seadistamist |

Kui Power Automate HTTP-trigger sinu litsentsiga ei tööta (premium connector), kasuta Discordi.

---

## Tulemus

Pärast harjutust on sul olemas:

1. **Moodul** `Saada-Teavitus.psm1` funktsiooniga `Send-AlertMessage`
2. **Konfigureerimisfail** `config.psd1` (ei lähe Gitti!)
3. **Integratsioon** — sinu eelmise tunni `suurimad_failid.ps1` skript saadab teavituse, kui leitakse fail üle 1 GB
4. **README.md** — kuidas moodulit kasutada

Käsurealt töötab see nii:

```powershell
Import-Module .\Saada-Teavitus.psm1

Send-AlertMessage -Message "Server DC01 kõvaketas 87% täis" -Severity Warning

Send-AlertMessage -Message "Kriitiline fail kustutatud!" -Severity Critical -Source "DC01"
```

Ja kanalis ilmub teade kohe.

---

## Nõuded

- Moodul peab olema `.psm1` failis ja käivitatav `Import-Module`-iga
- Funktsiooni nimi järgib **Verb-Noun** konventsiooni (`Get-Verb` näitab lubatud verbe)
- `-Severity` parameetril on lubatud ainult väärtused `Info`, `Warning`, `Critical`
- Webhook-URL **ei ole** koodis ega Gitis — loetakse keskkonnamuutujast või konfifailist
- `try/catch` käsitleb võrguvigu — skript ei jookse kokku, kui Discord on maas
- `Get-Help Send-AlertMessage` näitab sisulist abiinfot
- Moodul logib iga saatmise katse lokaalsesse logifaili

---

## Hea tava — checklist

Kui skript on valmis, kontrolli, kas kõik järgnev on täidetud. See pole pelgalt "kena oleks" — iga punkt on põhjus, miks päris tootmises skript katki läheb, kui seda ei tee:

- [ ] **Verb-Noun nimi** — `Send-AlertMessage`, mitte `saada_teade` ega `SendAlert`
- [ ] **`[CmdletBinding()]`** funktsiooni alguses — annab tasuta `-Verbose`, `-ErrorAction` ja muud standardsed parameetrid
- [ ] **`param()` blokk** parameetritega, mitte `$args[0]`-ga
- [ ] **`[Parameter(Mandatory)]`** kohustuslikele parameetritele
- [ ] **`[ValidateSet(...)]`** piiratud väärtustega parameetritele
- [ ] **Saladusi pole koodis** — ei URL-e, ei võtmeid, ei paroole
- [ ] **`.gitignore`** sisaldab `config.psd1` ja `*.log`
- [ ] **`try/catch`** iga `Invoke-RestMethod` ümber
- [ ] **Kommentaaripõhine abi** (`<# .SYNOPSIS ... #>`) funktsiooni kohal
- [ ] **Logimine** — iga saatmine kirjutatakse faili, koos ajatempliga
- [ ] **Väljumise kood** — kui teavitus ebaõnnestub, kas skript peab jätkama või katkestama? Otsusta ja kommenteeri.

---

## Ettevalmistus

### 1a. Discord webhook — kui valid Discordi

1. Ava Discord → loo oma jaoks privaatne server (või kasuta oma test-serverit)
2. Tekstikanal → **Kanali seaded** → **Integrations** → **Webhooks** → **New Webhook**
3. Pane nimi (nt `PS-Monitor`), kopeeri **Webhook URL**
4. URL näeb välja selline: `https://discord.com/api/webhooks/123456789/abcXYZ...`
5. **Hoia see URL saladuses** — kes iganes selle saab, saab su kanalisse kirjutada

### 1b. Power Automate — kui valid M365

1. Ava [make.powerautomate.com](https://make.powerautomate.com) oma Techno-TLN kontoga
2. **Create** → **Instant cloud flow** → trigger: **When a HTTP request is received**
3. Defineeri JSON-skeem (lihtne näide):
   ```json
   {
     "type": "object",
     "properties": {
       "message":  { "type": "string" },
       "severity": { "type": "string" },
       "source":   { "type": "string" }
     }
   }
   ```
4. Lisa järgmine samm: **Post message in a chat or channel** (Teams connector)
5. Salvesta — nüüd ilmub trigeri juurde **HTTP POST URL**. Kopeeri see.

---

## Skript samm-sammult

Harjutus on jagatud sammudeks. Proovi iga samm **ise** lahendada — vihje avaneb alles siis, kui jooksed seina otsa. Eesmärk on, et sa ise dokumentatsiooni loeksid ja katsetaksid, mitte ei kopeeriks lahendust.

---

### Samm 1 — esimene HTTP päring

Alusta lihtsalt: tee üks `.ps1` skript, mis saadab webhook-URL-ile ühe teate. Ära veel tee funktsiooni ega moodulit. Eesmärk — veenduda, et kanal töötab.

**Mida vajad:** `Invoke-RestMethod`, `ConvertTo-Json`, hash-table payload.

<details>
<summary>Vihje — Discord</summary>

```powershell
$url = "SINU_WEBHOOK_URL"

$payload = @{
    content  = "Tere Discordist! See on test PowerShellist."
    username = "PS-Monitor"
}

$json = $payload | ConvertTo-Json

Invoke-RestMethod -Uri $url -Method Post -Body $json -ContentType "application/json"
```

Discord ootab välja nimega `content`. Kui muudad välja nimesid, teade ei ilmu.

</details>

<details>
<summary>Vihje — Power Automate</summary>

```powershell
$url = "SINU_FLOW_URL"

$payload = @{
    message  = "Tere Teamsist!"
    severity = "Info"
    source   = "minu-arvuti"
}

$json = $payload | ConvertTo-Json

Invoke-RestMethod -Uri $url -Method Post -Body $json -ContentType "application/json"
```

Väljade nimed peavad **täpselt** vastama JSON-skeemile, mille PA-s defineerisid.

</details>

Kui teade kanalis ilmus — tubli, põhiasi töötab. Nüüd tee see kenamaks.

---

### Samm 2 — tee sellest funktsioon

Funktsioon peaks võtma vastu vähemalt `-Message` parameetri. URL on veel samas failis, saladused parandame hiljem.

**Mida vajad:** `function`, `param()`, tagastusväärtus.

<details>
<summary>Vihje</summary>

```powershell
function Send-AlertMessage {
    param(
        [string]$Message
    )

    $url = "SINU_WEBHOOK_URL"
    $payload = @{ content = $Message } | ConvertTo-Json

    Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json"
}

# test
Send-AlertMessage -Message "Esimene funktsioonikutse"
```

Pane tähele **Verb-Noun** nime — käivita `Get-Verb`, et näha lubatud verbe. `Send` on lubatud, `Push` ka, `saada` **ei ole**.

</details>

---

### Samm 3 — paki funktsioon mooduliks

Salvesta funktsioon faili `Saada-Teavitus.psm1` (`.psm1`, mitte `.ps1`!). Siis saab selle teistes skriptides importida.

**Mida vajad:** `.psm1` laiend, `Export-ModuleMember`, `Import-Module`.

<details>
<summary>Vihje</summary>

`Saada-Teavitus.psm1`:

```powershell
function Send-AlertMessage {
    param([string]$Message)
    # ... sama kood mis sammus 2
}

Export-ModuleMember -Function Send-AlertMessage
```

Kasutamine:

```powershell
Import-Module .\Saada-Teavitus.psm1 -Force

Send-AlertMessage -Message "Moodulist saadetud"
```

`-Force` on vajalik, kui redigeerid moodulit ja tahad uuesti importida.

</details>

---

### Samm 4 — parameetrid ja valideerimine

Lisa `-Severity` (Info / Warning / Critical) ja `-Source` (vabatekst). Severity järgi muutku teate välimus — näiteks Discordis `embed` värvidega (roheline / kollane / punane), Teamsis eraldi sõnum severity taseme kohta.

**Mida vajad:** `[Parameter(Mandatory)]`, `[ValidateSet(...)]`, `switch` või `if/elseif` lause.

<details>
<summary>Vihje</summary>

```powershell
function Send-AlertMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [string]$Source = $env:COMPUTERNAME
    )

    $color = switch ($Severity) {
        "Info"     { 3447003  }   # sinine
        "Warning"  { 16776960 }   # kollane
        "Critical" { 15158332 }   # punane
    }

    $payload = @{
        username = "PS-Monitor"
        embeds = @(@{
            title       = "[$Severity] $Source"
            description = $Message
            color       = $color
            timestamp   = (Get-Date).ToString("o")
        })
    } | ConvertTo-Json -Depth 4

    # ... Invoke-RestMethod
}
```

`ConvertTo-Json -Depth 4` on oluline — vaikimisi läheb sügavus 2 ja pesastatud objektid jäävad poolikuks.

</details>

---

### Samm 5 — veakäsitlus

Mis juhtub, kui Discord on maas? Kui URL on vale? Kui võrk puudub? Hetkel skript jookseb kokku. Lisa `try/catch`.

**Küsi endalt:** kui teavitus ebaõnnestub, kas ma tahan, et skript katkeks või jätkaks? Monitooringu puhul on tavaliselt **õige jätkata**, aga viga logida.

<details>
<summary>Vihje</summary>

```powershell
try {
    Invoke-RestMethod -Uri $url -Method Post -Body $json -ContentType "application/json" -ErrorAction Stop
    Write-Verbose "Teavitus saadetud: $Message"
}
catch {
    Write-Warning "Teavituse saatmine ebaõnnestus: $($_.Exception.Message)"
    # Siia võiks lisada ka logifaili kirjutamise
}
```

`-ErrorAction Stop` sunnib `Invoke-RestMethod`-i **viskama** erandi, mille `catch` kinni püüab. Ilma selleta läheks viga lihtsalt error-stream'i ja `catch` ei käivituks.

</details>

---

### Samm 6 — kommentaaripõhine abi

PowerShelli kasutaja peaks saama `Get-Help Send-AlertMessage`-i käivitada ja saama sisulise abi. See ei ole valikuline — päris moodulid **kõik** kirjutavad seda.

<details>
<summary>Vihje</summary>

```powershell
function Send-AlertMessage {
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
    param( ... )
}
```

Pane tähele: abi on **enne** `param()` plokki, mitte selle sees. PowerShell leiab selle automaatselt.

</details>

---

### Samm 7 — saladuste hoidmine

Praegu on URL koodis. See on **hea tava rikkumine** — kes iganes sinu Gitti näeb, saab sinu kanalisse spämmida. Vali üks järgnevatest:

**Variant A — keskkonnamuutuja (lihtsaim)**

```powershell
# Seadista üks kord (PowerShellis):
[Environment]::SetEnvironmentVariable("ALERT_WEBHOOK", "https://...", "User")

# Moodulis:
$url = $env:ALERT_WEBHOOK
if (-not $url) { throw "ALERT_WEBHOOK keskkonnamuutuja puudub" }
```

**Variant B — konfifail `.psd1`**

<details>
<summary>Vihje</summary>

`config.psd1`:
```powershell
@{
    WebhookUrl = "https://discord.com/api/webhooks/..."
    DefaultSeverity = "Info"
}
```

Moodulis:
```powershell
$configPath = Join-Path $PSScriptRoot "config.psd1"
$config = Import-PowerShellDataFile $configPath
$url = $config.WebhookUrl
```

`.gitignore`:
```
config.psd1
*.log
```

Lisa repos hoopis `config.example.psd1` koos tühja URL-iga — nii teab järgmine inimene, millist faili luua.

</details>

**Kontrolli:** `git status` ei tohi näidata `config.psd1`-i "untracked files" all pärast `.gitignore` lisamist. Kui näitab — `.gitignore` ei ole õiges kaustas või süntaks on vale.

---

### Samm 8 — logimine

Iga saatmine (nii õnnestunud kui ebaõnnestunud) läheb lokaalsesse logifaili. See on hindamatu, kui keegi hiljem küsib "miks me sellest probleemist teadet ei saanud?".

<details>
<summary>Vihje</summary>

```powershell
$logPath = Join-Path $env:TEMP "ps-alerts.log"
$aeg = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    Invoke-RestMethod ... -ErrorAction Stop
    Add-Content -Path $logPath -Value "$aeg [OK]   $Severity | $Source | $Message"
}
catch {
    Add-Content -Path $logPath -Value "$aeg [FAIL] $Severity | $Source | $Message | $($_.Exception.Message)"
}
```

Mõtle — kas logifaili tuleks ajapikku puhastada? Mis juhtub, kui see kasvab 10 GB suureks? (Vastus pole kohustuslik, aga mõtle sellele.)

</details>

---

### Samm 9 — integreeri eelmise harjutusega

Võta oma eelmise tunni `suurimad_failid.ps1` ja lisa sinna mooduli kasutamine. Kui leitakse fail üle 1 GB — saada Warning. Kui üle 5 GB — Critical.

<details>
<summary>Vihje</summary>

```powershell
Import-Module .\Saada-Teavitus.psm1 -Force

# ... eelmine kood, mis täidab $tulemus ...

foreach ($fail in $tulemus) {
    $baite = (Get-Item $fail.Tee -ErrorAction SilentlyContinue).Length

    if ($baite -ge 5GB) {
        Send-AlertMessage -Message "Väga suur fail: $($fail.Nimi) ($($fail.Suurus))" -Severity Critical
    }
    elseif ($baite -ge 1GB) {
        Send-AlertMessage -Message "Suur fail: $($fail.Nimi) ($($fail.Suurus))" -Severity Warning
    }
}
```

**Testi ettevaatlikult** — kui sul on kettal palju suuri faile, võid endale korraga 50 teavitust saata. Alusta suuremast piirist (nt 10 GB), kuni loogika töötab.

</details>

---

## Mida sa õppisid

| Mõiste / käsk | Tähendus |
|---|---|
| `Invoke-RestMethod` | HTTP-päringu saatmine REST API-le |
| `ConvertTo-Json -Depth N` | PowerShelli objekt → JSON-tekst |
| `.psm1` moodulifail | Funktsioonide kogumine ja taaskasutamine |
| `Import-Module -Force` | Mooduli laadimine / uuesti laadimine |
| `Export-ModuleMember` | Kontrollitakse, mis funktsioonid on väljast nähtavad |
| `[CmdletBinding()]` | Tasuta `-Verbose`, `-ErrorAction` jne |
| `[Parameter(Mandatory)]` | Kohustuslik parameeter |
| `[ValidateSet(...)]` | Piiratud väärtuste kontroll |
| `try/catch` | Vigade püüdmine |
| `<# .SYNOPSIS #>` | Kommentaaripõhine abi — `Get-Help` leiab |
| `Import-PowerShellDataFile` | `.psd1` konfifaili lugemine |
| `$env:MUUTUJA` | Keskkonnamuutuja lugemine |

---

## Lisaküsimused (valikuline)

1. Lisa `-Attachment` parameeter — saab kaasa panna CSV- või logifaili. Discordis kasuta `multipart/form-data`, Teamsis SharePointi linki.
2. Lisa "rate limiting" — kui sama teade saadetakse 5 minuti jooksul rohkem kui 3 korda, jäta vahele. Miks see oluline on?
3. Tee `Get-AlertLog` funktsioon, mis loeb logifaili ja kuvab viimased N kirjet objektina (mitte tekstina). Kuidas sellest siis `Where-Object`-iga filtreerida?
4. Kirjuta `Pester`-i test — mock Invoke-RestMethod, kontrolli, et õige payload saadetakse. (Pester on PowerShelli testiraamistik.)

---

## Tulemuse esitamine — Pull Request

Loo oma kausta järgnev struktuur:

```
tulemused/Eesnimi_P/
├── Saada-Teavitus.psm1          <- moodul
├── config.example.psd1          <- näidiskonfig (ILMA päris URL-ita)
├── suurimad_failid.ps1          <- uuendatud eelmine skript
├── .gitignore                   <- sisaldab config.psd1 ja *.log
└── README.md                    <- kuidas moodulit kasutada
```

**Enne commit-i kontrolli hoolikalt:**

```bash
git status
git diff --cached
```

Veendu, et `config.psd1` ja logifailid **ei ole** commit-is. Kui on — sa just lekkisid oma saladuse Gitti. Selle parandamine on valus (tuleb ajalugu ümber kirjutada), seega ennem vaata korralikult.

```bash
git checkout -b harjutus-teavitused-Eesnimi
git add tulemused/Eesnimi_P/
git commit -m "Lisa PowerShelli teavituste moodul — Eesnimi P"
git push -u origin harjutus-teavitused-Eesnimi
```

Ava GitHubis **Compare & pull request** ja loo PR pealkirjaga:

```
Teavituste moodul — Eesnimi P
```

**PR kirjeldusse lisa:**

- Kumba kanalit kasutasid (Discord / Power Automate)
- Screenshot, kus on näha, et teade kanalisse jõudis (katkesta URL välja!)
- Lühike mõttekäik: kas sinu moodul vastab iga "Hea tava" punkti nõudele? Mis jäi puudu?

---

*Kui jooksed probleemi otsa, ava repositooriumis **Issue** või küsi Teamsi kanalis. API-integreerimise vead on tüüpilised — pole häbi küsida.*