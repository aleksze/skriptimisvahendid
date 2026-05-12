# B — Serverite saadavuse monitor

Loeb hostide nimekirja CSV-failist, testib iga hosti võrgukättesaadavust ja salvestab tulemuse CSV-raportisse.

## Käivitamine

```powershell
# vaikimisi — kasutab hostid.csv praegusest kaustast
.\kontrolli-hostid.ps1

# oma hostide fail
.\kontrolli-hostid.ps1 -Sisend C:\minu\serverid.csv

# kohandatud väljundkaust
.\kontrolli-hostid.ps1 -Väljund C:\raportid\
```

