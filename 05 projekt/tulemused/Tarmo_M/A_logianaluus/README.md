# Logianalüüsi Süsteem — KIT-24 Iseseisev töö A

**Autor:** Tarmo M.  
**Ülesanne:** Teavitussüsteemi loomine PowerShellis ja logianalüüs Pythonis

---

## Projekti struktuur
Tarmo_M/ ├── Saada-Teavitus.psm1 # PowerShell moodul teavituste saatmiseks ├── Saada-Teavitus.ps1 # Demo skript teavituste genereerimiseks ├── analyysi_logi.py # Python logianalüüsi skript ├── ps-alerts.log # Genereeritud logifail (UTF-8) └── analyys_paevad.csv # CSV väljund päevade lõikes


---

## Komponendid

### 1. Saada-Teavitus.psm1 (PowerShell moodul)

Funktsioon teavituste logimiseks koos järgmiste võimalustega:
- Kolm raskusastet: `Info`, `Warning`, `Critical`
- Kaheksa erinevat teavituse tüüpi (ketas, protsess, teenus, võrk, temp, suur fail, varundus, sündmus)
- Võimalus saata teavitusi Slacki või meilile (konfigureeritav)
- Logimine UTF-8 formaadis ajatempliga

**Kasutamine:**
```powershell
Import-Module .\Saada-Teavitus.psm1
Saada-Teavitus -Tase Critical -Teade "Kriitiline tõrge" -Andmed "täiendav info"
2. analyysi_logi.py (Python analüüsiskript)
Analüüsib logifaili ja koostab:

Konsooli kokkuvõtte (periood, kogused, raskusastmed, top allikad)
ASCII-graafiku Critical teadete kohta päeva lõikes
CSV faili päevade lõikes statistikaga
Käivitamine:


python .\analyysi_logi.py ps-alerts.log
Väljund:

Periood:       2026-04-21 kuni 2026-04-21 (1 päeva)
Teadeid kokku: 60
  ├─ õnnestus:    52
  └─ ebaõnnestus: 8

Raskusaste:
  Info         20
  Warning      18
  Critical     22

Top allikad:
  1. DESKTOP-05P8344 — 60 teadet
...
Paigaldamine ja käivitamine
Eeltingimused
Windows PowerShell 5.1 või PowerShell 7+
Python 3.8 või uuem
Moodulid: requests (kui kasutad Slacki teavitusi)
Samm-sammuline käivitamine

# 1. Mine projekti kausta
cd "C:\Users\Lenovo\minu-projekt\skriptimisvahendid\05 projekt\Tarmo_M"

# 2. Impordi PowerShell moodul
Import-Module .\Saada-Teavitus.psm1 -Force

# 3. Genereeri testteavitused (kui Saada-Teavitus.ps1 on olemas)
.\Saada-Teavitus.ps1

# 4. Kontrolli logifaili
Get-Content $env:TEMP\ps-alerts.log -TotalCount 5

# 5. Kopeeri logifail projekti kausta
Copy-Item "$env:TEMP\ps-alerts.log" ".\ps-alerts.log"

# 6. Analüüsi Pythonis
python .\analyysi_logi.py .\ps-alerts.log

# 7. Kontrolli CSV väljundit
Get-Content .\analyys_paevad.csv
Logi formaat
YYYY-MM-DD HH:MM:SS [STAATUS] SEVERITY | ALLIKAS | SÕNUM [| VIGA]
Näide:

2026-04-21 11:31:35 [OK]   Critical | DESKTOP-05P8344 | VÄGA SUUR FAIL: 51ba2722-10ca-4926-ac70-f2cbdacbeb84.vhdx (24.8 GB)
CSV väljundi struktuur
Päev	Teateid kokku	Info	Warning	Critical	Ebaõnnestunud
2026-04-21	60	20	18	22	8
Märkused
Logifail salvestatakse vaikimisi $env:TEMP\ps-alerts.log
Python skript toetab automaatset kodeeringu tuvastust (UTF-8, UTF-16, cp1257)
Mitmerealised sõnumid (nt failiteed) käsitletakse automaatselt