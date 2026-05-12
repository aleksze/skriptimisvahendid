# PowerShell: suurimad failid ja teavitused

## Kirjeldus

See projekt sisaldab PowerShelli skripti, mis otsib kasutaja arvutist 10 kõige suuremat faili, salvestab tulemuse CSV-faili ning vajadusel saadab teavituse Discordi (või muu REST API) kaudu.

Skript on mõeldud süsteemiadministraatori töö automatiseerimiseks, et tuvastada kiiresti kettaruumi kasutavad suured failid.

---

## Kuidas see töötab

1. Skript otsib rekursiivselt kõik failid kasutaja kodukaustas.
2. Failid sorteeritakse suuruse järgi kahanevalt.
3. Valitakse 10 kõige suuremat faili.
4. Tulemused teisendatakse loetavasse formaati (KB / MB / GB).
5. Andmed salvestatakse CSV-faili.
6. Kui fail ületab teatud piiri, saadetakse teavitus (kui moodul on seadistatud).

---

## Failid

- **Saada-Teavitus.psm1** - PowerShelli moodul funktsiooniga **Send-AlertMessage**  
- **config.example.psd1** - näidiskonfiguratsioon (ilma reaalse webhookita) 
- **Discord_tulemus.png**  - Discord channeli pilt

---

## Failide kirjeldus

### `suurimad_failid.ps1`
Põhiskript, mis:
- otsib failid
- sorteerib suuruse järgi
- loob CSV väljundi
- (valikuliselt) saadab teavitusi

---

### `Saada-Teavitus.psm1`
PowerShelli moodul, mis:
- saadab teate Discord webhooki või muu REST API kaudu
- toetab tasemeid: Info, Warning, Critical
- logib kõik saatmiskatsed

---

### `config.example.psd1`
Näidis konfiguratsioonifail.

- sisaldab webhook URL-i vormi
- kasutatakse ainult mallina
- **päris config.psd1 ei ole Gitis**

---

### `.gitignore`
Määrab failid, mida Git ei jälgi:
- `config.psd1` (salajane konfiguratsioon)
- `*.log` (logifailid)

---

## Kasutamine

```powershell
# Mooduli import
Import-Module .\Saada-Teavitus.psm1

# Skripti käivitamine
.\suurimad_failid.ps1