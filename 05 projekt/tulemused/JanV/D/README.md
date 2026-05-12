# D — Süsteemi inventuur

Kogub arvuti kohta süsteemiinfot (OS, CPU, RAM, kettad, võrk) ja salvestab JSON-faili. Töötab Windowsis, macOS-is ja Linuxis.

## Ettevalmistus

```bash
pip install psutil
```

## Käivitamine

```bash
# vaikimisi — salvestab inventuur_<hostname>_<kuupäev>.json
python inventuur.py

# kohandatud failinimi
python inventuur.py --väljund minu_arvuti.json

# prindi JSON konsooli (torustikus kasutamine)
python inventuur.py --stdout
python inventuur.py --stdout | jq .cpu
```

