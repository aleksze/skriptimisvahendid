# Süsteemi inventuur

## Paigaldus

pip install -r requirements.txt

## Käivitamine

Vaikimisi (salvestab JSON faili):
python inventuur.py

Oma failinimega:
python inventuur.py --väljund minu_inventuur.json


## Testitud

- Windows 11
- Linux Mint

## Platvormi märkused

- Linux: CPU mudel loetakse /proc/cpuinfo failist
- Kõik muud väljad töötavad ristplatvormiliselt