# Ülesanne C — Kaustade puhastus

**Kursus:** KIT-24
**Autor:** Tarmo M
**Keel:** Bash
**Tööriistad:** `find`, `tar`, `du`, `realpath`, `set -euo pipefail`

---

## Eesmärk

Skript leiab kaustast failid, mis on vanemad kui N päeva, **arhiveerib** need `tar.gz`-i ja seejärel **kustutab** originaalid. Kustutus toimub **ainult** siis, kui arhiveerimine õnnestus — arhiiv on turvavõrk.

See on klassikaline admin-ülesanne: server hakkab täis saama, vanad logid `/var/log` või `/tmp` vajavad rutiinset puhastust.

---

## Failid

| Fail | Sisu |
|---|---|
| `puhasta.sh` | Põhiskript |
| `test-andmed-setup.sh` | Loob `/tmp/test-puhastus` 5 vana + 3 värske failiga |
| `arhiiv_<kuupäev>_<kellaaeg>.tar.gz` | Tekib käivitamisel jooksvasse kausta |
| `README.md` | Käesolev dokument |

---

## Käivitatavaks tegemine

```bash
chmod +x puhasta.sh test-andmed-setup.sh
```

---

## Kasutamine

```bash
# Abi
./puhasta.sh --help

# Eelvaade — ei muuda midagi
./puhasta.sh /tmp/test-puhastus 7 --dry-run

# Päris jooks — arhiveerib ja kustutab
./puhasta.sh /tmp/test-puhastus 7
```

### Argumendid

| Argument | Tähendus |
|---|---|
| `<kaust>` | Kaust, mida puhastada (peab olemas olema) |
| `<päevi>` | Positiivne täisarv — failid vanemad kui N päeva |
| `--dry-run` | Näita, mida teeks, aga ära muuda midagi |
| `--help`, `-h` | Näita abiteksti |

### Exit-koodid

| Kood | Tähendus |
|---|---|
| `0` | Edu |
| `2` | Valed argumendid (puudu, vale tüüp, kaust olematu) |
| `3` | Keelatud kaust (mustade nimekiri) |
| `4` | Arhiveerimine ebaõnnestus → kustutust EI tehtud |

---

## Väljund

```
Puhastus: /tmp/test-puhastus
Vanusepiir: 7 päeva
Leidsin 5 faili (0 MB).
Arhiveerin: arhiiv_2026-04-21_101502.tar.gz
Arhiiv loodud (4,0K).
Kustutan 5 faili...
Valmis! Vabanes 0 MB.
```

`--dry-run` korral:

```
Puhastus: /tmp/test-puhastus
Vanusepiir: 7 päeva
Leidsin 5 faili (0 MB).
DRY RUN — järgmist teeksin:
  1. Arhiveeriks 5 faili → arhiiv_2026-04-21_101502.tar.gz
  2. Kustutaks originaalid (0 MB)

Eelvaade (kuni 10 faili):
  /tmp/test-puhastus/vana_1.log
  /tmp/test-puhastus/vana_2.log
  ...
```

---

## Turvalisuse otsused

### 1. `set -euo pipefail`

Skripti algus on kolm rida, mis eraldavad amatöörskripti adminskriptist:

- `set -e` — katkesta kohe esimese vea peale. **Kriitiline** — kui `tar` ebaõnnestub, skript **ei jõua kustutuseni**.
- `set -u` — kasutamata muutuja = viga. Tõkestab typo-vead (`$kausst` vs `$kaust`).
- `set -o pipefail` — torustikus arvestatakse ka esimese käsu veaga.

### 2. Mustade nimekiri

Skripti sees on massiv `KEELATUD`, mis sisaldab teid, mida **kunagi** ei tohi puhastada:

```
/  /home  /root  /usr  /etc  /var  /bin  /sbin  /boot  /opt  $HOME
```

**Miks just need?**
- `/`, `/usr`, `/etc`, `/bin`, `/sbin`, `/boot` — operatsioonisüsteemi tuum, kustutus = surnud süsteem.
- `/home`, `/root`, `$HOME` — kasutajate andmed, kustutus = andmekaotus.
- `/var`, `/opt` — paigaldatud tarkvara ja andmebaasid.

`/tmp` **ei ole keelatud** — see on tegelik puhastuse sihtkoht. Kasutaja vastutus on anda spetsiifiline alamtee (`/tmp/midagi`), mitte `/tmp` ennast tühjaks lasta (kuigi see töötaks).

### 3. `realpath` sümbol-linkide vastu

`realpath` lahendab sümbol-lingid ja suhtelised teed. Nii ei saa keegi `./puhasta.sh ../../../../ 0` trikiga juurkausta hävitada — `realpath` muudab selle `/`-ks ja mustade kontroll lööb kinni.

### 4. Arhiveeri-enne-kustuta loogika

```bash
if ! find ... | tar --null -czf ... -T -; then
    viga "arhiveerimine ebaõnnestus. Ei kustuta midagi."
    exit 4
fi

# Kustutus on EI eraldi käsk peale tar õnnestumist
find ... -delete
```

Kui ketas on täis, õigused puudu või `tar` mingil põhjusel kukub — `set -e` + eraldi `if`-haru garanteerivad, et `find -delete` käsuni ei jõuta.

### 5. `find -print0` + `tar --null`

Failinimedes võib olla tühikuid, jutumärke või isegi reavahetusi. `-print0` eraldab nimed null-baidiga (`\0`), mida ei saa nimes esineda — ainus 100% turvaline viis nimekirja edastada.

---

## Dry-run testimine

```bash
# 1. Loo ohutu test-kaust
./test-andmed-setup.sh

# 2. Vaata, mida teeks (ei muuda midagi!)
./puhasta.sh /tmp/test-puhastus 7 --dry-run

# 3. Kontrolli, et failid on alles
ls -la /tmp/test-puhastus

# 4. Kui dry-run nägi õigeid faile (5 vana_*.log), siis päris jooks:
./puhasta.sh /tmp/test-puhastus 7

# 5. Kontrolli tulemust — peaks olema 3 värske faili + arhiivifail
ls -la /tmp/test-puhastus
ls -la arhiiv_*.tar.gz

# 6. Avaa arhiiv ja vaata, mis sees on
tar -tzf arhiiv_*.tar.gz
```

**Veatestid:**

```bash
./puhasta.sh                       # exit 2 — argumendid puudu
./puhasta.sh /olematu 7            # exit 2 — kaust olematu
./puhasta.sh /tmp/test abc         # exit 2 — päevi pole arv
./puhasta.sh / 7                   # exit 3 — keelatud kaust
./puhasta.sh /home 7               # exit 3 — keelatud kaust
```

---

## Kui PowerShell, ee... Bash ei luba käivitada

Kui näed `Permission denied`:

```bash
chmod +x puhasta.sh
```

Kui skripti ei leita:

```bash
./puhasta.sh ...        # mitte lihtsalt "puhasta.sh"
```

---

## Teadaolevad puudused

1. **`wc -l` ja reavahetused failinimedes.** Faili­arvu loendamine `find ... | wc -l` kaudu loeb valesti, kui mõnes failinimes on `\n`. Produktsioonis kasutaks `find ... -print0 | tr -cd '\0' | wc -c`. Kustutus ja arhiveerimine ise on turvalised (`-print0` + `--null`), ainult statistika number võib olla väike vale.
2. **Arhiivi sihtkaust.** Praegu `arhiiv_*.tar.gz` jääb jooksvasse kausta. Lisaküsimus 2 (`--arhiivi-kaust`) jäi tegemata.
3. **Laiendi filter puudub.** Lisaküsimus 3 (`--laiend *.log`) jäi tegemata — praegu puhastame kõiki failitüüpe.
4. **Logifail.** Lisaküsimus 1 (`~/puhastus.log`-i kirjutamine) jäi tegemata — kogu väljund on ainult konsoolis.
5. **Vanade arhiivide rotatsioon.** Lisaküsimus 4 (vanemate kui 6 kuu arhiivide kustutamine) jäi tegemata.
6. **Tühjad alamkaustad jäävad alles.** Skript kustutab `-type f` (ainult failid), mis on teadlik valik (kaust säilib), aga tagajärjeks on tühjad alamkaustad.

---

## Mida õppisin

| Mõiste | Tähendus |
|---|---|
| `set -euo pipefail` | Turvaline skripti algus — katkesta vea peale |
| `[[ ... ]]` | Tingimus (bash-laiendiga, parem kui `[ ... ]`) |
| `>&2` | Suuna väljund stderr-ile (vead eraldi stdout-ist) |
| `find -mtime +N` | Muutmise aeg üle N päeva tagasi |
| `find -print0` + `xargs -0` / `tar --null` | Turvaline nimede käsitlus (tühikud, erisümbolid) |
| `tar -czf ... -T -` | Tar loeb failide nimekirja stdin-ist |
| `realpath` | Tegelik absoluutne tee (lahendab sümbol-lingid) |
| `[[ $x =~ ^[0-9]+$ ]]` | Regex-kontroll |
| `cat <<EOF ... EOF` | Mitmerealine string (heredoc) |
| `case "$1" in ... esac` | Lippude parsing `while`-tsüklis |
| `exit <kood>` | Väljumisstaatus (0 = edu, mitte-null = viga) |
| `local muutuja=...` | Funktsiooni-sisene muutuja (ei lekita globaali) |

---

## Allikad

- GNU `find` man-leht — `man find`, eriti `-mtime`, `-print0`, `-delete`
- GNU `tar` man-leht — `man tar`, eriti `--null` ja `-T -`
- Bash `set` builtin — `help set`
- [Greg's Wiki: BashFAQ/020 — How can I find and safely handle file names containing newlines, spaces or both?](https://mywiki.wooledge.org/BashFAQ/020)