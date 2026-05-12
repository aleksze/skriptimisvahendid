# Serverite monitor

See PowerShelli skript loeb hostide nimekirja CSV-failist, kontrollib nende kättesaadavust ning salvestab tulemused eraldi CSV-väljundisse.

## Projekti failid

- `kontrolli-hostid.ps1` – põhiskript
- `hostid.csv` – sisendfail hostide nimekirjaga
- `saadavus_2026-04-21.csv` – näidisväljund
- `README.md` – kasutusjuhend ja disainiotsuste kirjeldus

## Käivitamine

Ava PowerShell ja liigu projekti kausta:

```powershell
cd "C:\Users\tahka\skriptimisvahendid\05 projekt\tulemused\Aivar_T\B_serverite_monitor"
```

Käivita skript vaikimisi sisendfailiga:

```powershell
powershell -ExecutionPolicy Bypass -File .\kontrolli-hostid.ps1
```

Käivita skript enda määratud sisendfailiga:

```powershell
powershell -ExecutionPolicy Bypass -File .\kontrolli-hostid.ps1 -SisendCsv .\hostid.csv
```

## Mida skript teeb

Skript:

- loeb hostid CSV-failist
- kontrollib hosti ja pordi kättesaadavust
- märgib tulemuseks `OK` või `FAIL`
- lisab kontrollimise aja
- salvestab tulemused kuupäevaga CSV-faili
- kuvab lõpus kokkuvõtte konsoolis

## Disainiotsused

### `[CmdletBinding()]` ja `param()`

Kasutasin PowerShelli korrektset skriptistruktuuri koos `param()` blokiga, et sisendfaili ja väljundit saaks vajadusel muuta.

### CSV sisend `Import-Csv` abil

Hostide nimekiri loetakse `Import-Csv` abil. See on sobiv lahendus, sest sisend on tabelikujuline ja veerud on ette teada.

### Funktsioon `Test-HostStatus`

Tegin eraldi funktsiooni `Test-HostStatus`, et ühe hosti kontrolli loogika oleks ülejäänud skriptist eraldi.

### Veakindlus

Kui ühe hosti kontroll ebaõnnestub, siis skript ei katkesta kogu tööd. Selle hosti tulemuseks märgitakse `FAIL` ja ülejäänud kontrollid jätkuvad.

### Väljund CSV-faili

Tulemused salvestatakse CSV-faili, et neid oleks lihtne hiljem avada Excelis või töödelda edasi muudes tööriistades.

### Kokkuvõte konsoolis

Lõpus kuvatakse lühike kokkuvõte, mitu hosti olid kättesaadavad ja mitu mitte. See annab kiire ülevaate ilma CSV-faili avamata.

## Autor

Aivar T