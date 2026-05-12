# Ülesanne A — Logianalüüsi skript  
**Autor:** Martin E  
**Kursus:** KIT-24  
**Keel:** Python  
**Fail:** `analyysi_logi.py`

## Eesmärk
Skript analüüsib teavituste mooduli logifaili (`ps-alerts.log`) ja koostab:
- konsooli kokkuvõtte perioodi, raskusastmete ja allikate kohta  
- ASCII-graafiku Critical teadete jaotusest  
- CSV-faili (`analyys_paevad.csv`), mis sisaldab päevade kaupa detailset statistikat

## Käivitamine

### Vaikimisi sisendfailiga:
`python analyysi_logi.py`

### Määratud sisend- ja väljundfailiga:
`python analyysi_logi.py --input näidis_ps-alerts.log --output minu_raport.csv`

### Nõuded
- Python 3.10+  
- Moodulid: argparse, csv, datetime, collections, pathlib  
  (kõik on Pythoniga kaasas)

## Sisendi formaat
Logifailis on väljad eraldatud tühimärkidega (TAB või mitu tühikut):

1. Ajatempel `YYYY-MM-DD HH:MM:SS`  
2. Staatus `[OK]` või `[FAIL]`  
3. Severity: `Info`, `Warning`, `Critical`  
4. Allikas (hostinimi)  
5. Sõnum (võib sisaldada lisavälju)

Skript on robustne ja suudab lugeda nii TAB- kui tühikupõhist formaati.

## Väljund konsooli (näide)

Periood: 2026-04-14 kuni 2026-04-17 (4 päeva)  
Teateid kokku: 10  
Õnnestus: 9  
Ebaõnnestus: 1  

Raskusaste:  
- Info: 4  
- Warning: 3  
- Critical: 3  

Top allikad:  
- DESKTOP-42 — 5 teadet  
- DC01 — 4 teadet  
- LAPTOP-07 — 1 teade  

Critical teated päeva lõikes:  
- 2026-04-14: █ (1)  
- 2026-04-15: █ (1)  
- 2026-04-16: █ (1)  
- 2026-04-17: - (0)

## CSV väljund
Fail `analyys_paevad.csv` sisaldab:

Päev | Teateid kokku | Info | Warning | Critical | Ebaõnnestunud  
--- | --- | --- | --- | --- | ---  
2026-04-14 | 3 | 1 | 1 | 1 | 0  
2026-04-15 | 3 | 1 | 1 | 1 | 1  
2026-04-16 | 3 | 1 | 1 | 1 | 0  
2026-04-17 | 1 | 1 | 0 | 0 | 0  

## Disainiotsused

### Parsimine  
- Kasutan `split()` mitte `split("\t")`, et toetada nii TAB-e kui tühikuid.  
- Vigased read tagastavad `None` ja skript jätkab tööd.

### Andmestruktuurid  
- Päevade kaupa kogumiseks kasutan `defaultdict(Counter)`  
- Allikate ja severity jaoks `Counter`

### Kuupäevad  
- Ajatempel teisendatakse `datetime` objektiks  
- Päevad salvestatakse `date()` kujul

### ASCII-graafik  
- Critical-teadete arv kuvatakse sümbolitega `█`  
- Kui teateid pole, kuvatakse `-`

### Tühja logifaili käsitlemine  
- Kui logi on tühi või kõik read on vigased, prindib skript selge teate  
- CSV luuakse siiski, kuid sisaldab ainult päist

## Vigaste ridade käsitlemine
Skript ei katkesta tööd.  
Näide: “X vigast rida jäeti vahele.”

## Testimine
Kaustas on näidisfail `näidis_ps-alerts.log`, mida saab kasutada skripti kontrollimiseks.


# Ülesanne B — Hostide saadavuse kontroll PowerShelliga

## Ülevaade
Skript **kontrolli-hostid.ps1** loeb hostide nimekirja CSV-failist, testib nende saadavust (ICMP või TCP) ning salvestab tulemused uude CSV-faili.  
Lahendus on loodud vastavalt kursuse *Skriptimisvahendid (KIT-24)* juhistele.

## Funktsionaalsus
- Loeb sisendfaili `hostid.csv`
- Kontrollib iga hosti saadavust:
  - Kui `port = 0` → kasutatakse ICMP ping’i
  - Kui `port > 0` → tehakse TCP ühenduse katse
- Koostab kokkuvõtte:
  - Hostinimi  
  - IP/hostname  
  - Port  
  - Kirjeldus  
  - Staatus: **OK** või **FAIL**
- Salvestab tulemuse faili `tulemus.csv`
- Loob väljundkausta automaatselt, kui seda pole olemas

## Kasutamine

### Vaikimisi:
```powershell
.\kontrolli-hostid.ps1

# Ülesanne C — Kaustade puhastamise skript (Bash)  
**Autor:** Martin E  
**Kursus:** KIT-24  
**Failid:** `puhasta.sh`, `test-andmed-setup.sh`

## Eesmärk
Skript `puhasta.sh` otsib etteantud kaustast failid, mis on vanemad kui määratud arv päevi, pakib need turvaliselt tar.gz arhiivi ning kustutab originaalid **ainult siis**, kui arhiveerimine õnnestub.  
Lisaks toetab skript `--dry-run` režiimi, mis võimaldab puhastust turvaliselt testida.

Testandmete loomiseks on eraldi skript `test-andmed-setup.sh`, mis loob 5 vana ja 3 värsket faili kontrollimiseks.

---

## Funktsionaalsus

### `puhasta.sh`
- Kontrollib argumente: kaust, päevade arv, valikuline `--dry-run`
- Keelab puhastamise ohtlikes süsteemikaustades (must nimekiri)
- Leiab kõik failid, mis on vanemad kui N päeva
- Arvutab failide kogusuuruse
- Dry-run režiimis:
  - näitab, mida teeks  
  - **ei arhiveeri ega kustuta**
- Päris režiimis:
  - loob arhiivi `arhiiv_YYYY-MM-DD_HHMMSS.tar.gz`
  - kustutab vanad failid ainult siis, kui arhiiv loodi edukalt
- Kuvab selge kokkuvõtte

### `test-andmed-setup.sh`
- Loob kausta `/c/temp/test-puhastus`
- Genereerib:
  - 5 vana faili (10 päeva vanad)
  - 3 värsket faili (tänased)
- Kuvab kausta sisu kontrollimiseks

---

## Kasutamine

### Testandmete loomine:
```bash
./test-andmed-setup.sh

