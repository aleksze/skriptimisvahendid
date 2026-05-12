# Süsteemi inventuur

## Ülevaade

See skript kogub arvuti süsteemi infot (OS, CPU, RAM, kettad ja võrk) ning salvestab selle JSON formaadis. Lisaks on võimalik saata kokkuvõte Discord webhooki kaudu.

---

## Testitud operatsioonisüsteemid

Skripti on testitud järgmistel platvormidel:

- Windows 10 / Windows 11
- Linux (Ubuntu 22.04 – osaliselt testitud)
- macOS (teoreetiline ühilduvus, ei ole täielikult testitud)

---

## Platvormide ühilduvus

### Kõigil platvormidel töötavad väljad:

- Host nimi (`socket.gethostname()`)
- Kasutaja nimi (`getpass.getuser()`)
- Python versioon (`platform.python_version()`)
- OS nimi (`platform.system()`)
- OS versioon (`platform.version()`, `platform.release()`)
- CPU südamike arv (`psutil.cpu_count`)
- RAM info (`psutil.virtual_memory`)
- Võrgukaartide loetelu (`psutil.net_if_addrs`)
- JSON eksport (`json.dumps`)
- CLI argumendid (`argparse`)

---

## Failid

- JSON fail genereeritakse automaatselt:

Näide: **inventuur_PCNIMI_KUUPAEV.json**

- TXT fail annab teada millised paketti on vaja alla laadida

Näide: **requirements.txt**

- Python fail on esmane skript

Näide: **inventuur.py**



