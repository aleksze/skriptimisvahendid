# Iseseisev töö — Rainer V

KIT-24

## Ülesanded

### A. Logianalüüs (Python)

Analüüsib ps-alerts.log faili ja koostab kokkuvõtte.

```bash
python analyysi_logi.py ps-alerts.log
python analyysi_logi.py ps-alerts.log --väljund tulemus.csv
```

### B. Serverite monitor (PowerShell)

Kontrollib hostide saadavust CSV-nimekirja põhjal.

```powershell
.\kontrolli-hostid.ps1
.\kontrolli-hostid.ps1 -Sisend "minu_hostid.csv"
```

### D. Süsteemi inventuur (Python)

Kogub süsteemi info ja salvestab JSON-i.

```bash
pip install -r requirements.txt
python inventuur.py
python inventuur.py --stdout
```

Testitud Windows 11 ja Linux (WSL2 Debian) peal.
