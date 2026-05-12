Ülesanne B — Serverite saadavuse monitor
Kursus: KIT-24 Autor: Tarmo M Keel: PowerShell Moodulid/käsud: Test-Connection, Test-NetConnection, Import-Csv, Export-Csv

Eesmärk
Skript loeb hostide nimekirja CSV-failist, kontrollib iga hosti kättesaadavust (TCP-port või ICMP ping) ning salvestab tulemused kuupäevaga CSV-faili. Kui mõni host on maas ja teavituste moodul on saadaval, saadab hoiatuse.

Failid
Fail	Sisu
kontrolli-hostid.ps1	Põhiskript
hostid.csv	Sisend — kontrollitavate hostide nimekiri
saadavus_<kuupäev>.csv	Väljund — tekib käivitamisel
README.md	Käesolev dokument
Kasutamine

# Vaikeseadetega (loeb hostid.csv samast kaustast)
.\kontrolli-hostid.ps1

# Oma sisend-failiga
.\kontrolli-hostid.ps1 -InputCsv minu-hostid.csv

# Väljund teise kausta
.\kontrolli-hostid.ps1 -OutputDir C:\Logid
Kui PowerShell ei luba skripti käivitada

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Sisend-CSV formaat

nimi,host,port,kirjeldus
google,google.com,443,Avalik võrgutest
oma-ruuter,192.168.1.1,,Koduvõrgu ping (port tühi = ICMP)
nimi — vabalt valitav lühinimi
host — DNS-nimi või IP
port — TCP-port (kui tühi, kasutatakse ICMP pingi)
kirjeldus — vaba tekst
Väljund
Konsoolis:

Kontrollin 5 hosti...

  google          google.com:443               OK    23 ms
  github          github.com:443               OK    31 ms
  oma-ruuter      192.168.1.1:80               OK    2 ms
  olematu         ei-ole-olemas.invalid:443    FAIL  -
  localhost-ssh   127.0.0.1:22                 OK    1 ms

Kokkuvõte: 4 / 5 OK, 1 maas
Tulemus salvestatud: saadavus_2026-04-21.csv
CSV-fail (saadavus_<kuupäev>.csv):

Nimi	Host	Port	Olek	Viivitus_ms	Kontrollitud	Kirjeldus
google	google.com	443	OK	23	2026-04-21 10:15:02	Avalik võrgutest