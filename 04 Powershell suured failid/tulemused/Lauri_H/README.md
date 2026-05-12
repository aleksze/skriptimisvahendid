See skript kontrollib, kas arvutisse paigaldatud ID-tarkvara on ajakohane.
Skript võrdleb kohalikku versiooni uusima versiooniga ning saadab teavituse, kui uuendus on vajalik.

Kasutada tuleb ka varasemalt kasutatud Saada-Teavitus.psm1, 
Vaja seadistada config.psd1, Näidis config.example.psd1, 
Veendu, et kõik failid oleks samas kaustas
# PowerShell harjutus – Teavitussüsteem

## 📌 Kirjeldus

Selle projekti eesmärk on luua PowerShelli skript, mis leiab kasutaja arvutist suured failid ning saadab nende kohta teavituse Discordi webhooki kaudu.

Lahendus koosneb kahest osast:

1. Skript, mis leiab suurimad failid kasutaja kodukaustast
2. Moodul, mis saadab teavitusi REST API kaudu

---

## ⚙️ Funktsionaalsus

* Otsib rekursiivselt kõik failid kasutaja määratud kaustast
* Leiab suurimad failid (Top 10)
* Kuvab failisuuruse inimloetaval kujul (KB, MB, GB)
* Ekspordib tulemused CSV faili
* Saadab Discordi teavituse, kui leitakse:

  * ⚠️ Suur fail (> 1GB)
  * ❗ Väga suur fail (> 5GB)

---

## 📁 Projekti struktuur

```
.
├── suurimad_failid.ps1     # Põhiskript
├── Saada-Teavitus.psm1    # Teavitusmoodul
├── config.psd1            # Konfiguratsioon (ei lähe Git-i)
├── suurimad_failid.csv    # Tulemuste fail
└── README.md
```

---

## 🔐 Konfiguratsioon

Fail `config.psd1` sisaldab webhook URL-i:

```powershell
@{
    WebhookUrl = "SINU_DISCORD_WEBHOOK_URL"
}
```

⚠️ NB! Seda faili ei tohi GitHubi üles laadida (lisa `.gitignore` faili).

---

## 🚀 Kasutamine

### 1. Impordi moodul

```powershell
Import-Module .\Saada-Teavitus.psm1
```

### 2. Käivita skript

```powershell
.\suurimad_failid.ps1
```

Või määra kaust:

```powershell
.\suurimad_failid.ps1 -Path "C:\Users\Kasutaja\Downloads"
```

---

## 📬 Teavitused

Teavitused saadetakse Discordi webhooki kaudu.

Näited:

* `[Warning] Suur fail: example.iso (2.3 GB)`
* `[Critical] Väga suur fail: backup.zip (5.8 GB)`

---

## 🛠 Kasutatud tehnoloogiad

* PowerShell
* REST API (`Invoke-RestMethod`)
* Discord Webhook

---

## 📈 Võimalikud täiendused

* Logifaili loomine
* Failitüüpide filtreerimine
* Ajastatud käivitamine (Task Scheduler)
* E-posti teavitused

---

## 👤 Autor

Lauri H
See skript kontrollib, kas arvutisse paigaldatud ID-tarkvara on ajakohane.
Skript võrdleb kohalikku versiooni uusima versiooniga ning saadab teavituse, kui uuendus on vajalik.

Kasutada tuleb ka varasemalt kasutatud Saada-Teavitus.psm1
Vaja seadistada config.psd1, Näidis config.example.psd1
Veendu, et kõik failid oleks samas kaustas


