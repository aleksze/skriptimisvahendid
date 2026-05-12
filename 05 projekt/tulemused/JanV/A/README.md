# A — Logianalüüsi skript

Loeb teavituste logifaili ja kuvab kokkuvõtte konsooli + salvestab CSV-faili.

## Käivitamine

```bash
# lihtsaim — kasutab ps-alerts.log praegusest kaustast
python analyysi_logi.py

# oma logifail
python analyysi_logi.py minulogi.log

# kohandatud CSV väljundfail
python analyysi_logi.py ps-alerts.log --väljund raport.csv
```
