#!/bin/bash
# =============================================================================
# puhasta.sh — Kaustade puhastus (Ülesanne C, KIT-24)
# Autor: Tarmo M
#
# Leiab antud kaustast failid, mis on vanemad kui N päeva, arhiveerib nad
# tar.gz-i ja kustutab seejärel originaalid. Kustutus toimub AINULT siis,
# kui arhiveerimine õnnestus (set -e + eraldi sammud).
# =============================================================================

set -euo pipefail
# set -e          — katkesta esimese vea peale (kaitseb kustutuse eest, kui tar läks viga)
# set -u          — kasutamata muutuja = viga (typo-vastane kaitse)
# set -o pipefail — torustikus loeb ka esimese käsu vea

# --- Globaalsed muutujad (täidetakse argumentide parsimisel) ------------------
KAUST=""
PÄEVI=""
DRY_RUN=false

# Keelatud teed — neid ei tohi kunagi puhastada (süsteemi juur + koduvasted)
KEELATUD=("/" "/home" "/root" "/usr" "/etc" "/var" "/bin" "/sbin" "/boot" "/opt" "$HOME")

# -----------------------------------------------------------------------------
# kasuta() — prindib kasutusjuhise
# -----------------------------------------------------------------------------
kasuta() {
    cat <<EOF
Kasutamine: $0 <kaust> <päevi> [--dry-run]

  <kaust>     Kaust, mida puhastada
  <päevi>     Faile vanemaid kui see päevade arv arhiveerida ja kustutada
  --dry-run   Näita, mida teeks, aga ära muuda midagi
  --help      Näita seda abi

Näited:
  $0 /tmp/test-puhastus 7
  $0 /tmp/test-puhastus 7 --dry-run

Exit-koodid:
  0  edu
  2  valed argumendid
  3  keelatud kaust
  4  arhiveerimine ebaõnnestus
EOF
}

# -----------------------------------------------------------------------------
# viga(sõnum) — prindib veateate stderr-i ja jätab koodi alla, et väljuda
# -----------------------------------------------------------------------------
viga() {
    echo "Viga: $1" >&2
}

# -----------------------------------------------------------------------------
# parsi_argumendid("$@") — täidab KAUST, PÄEVI, DRY_RUN
# -----------------------------------------------------------------------------
parsi_argumendid() {
    local positsioonilised=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                kasuta
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                viga "tundmatu lipp '$1'"
                kasuta >&2
                exit 2
                ;;
            *)
                positsioonilised+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#positsioonilised[@]} -ne 2 ]]; then
        viga "peab olema täpselt kaks positsioonilist argumenti (kaust + päevi)."
        kasuta >&2
        exit 2
    fi

    KAUST="${positsioonilised[0]}"
    PÄEVI="${positsioonilised[1]}"
}

# -----------------------------------------------------------------------------
# valideeri_sisend() — kontrollib, et kaust on olemas ja päevi on positiivne arv
# -----------------------------------------------------------------------------
valideeri_sisend() {
    if [[ ! -d "$KAUST" ]]; then
        viga "kaust '$KAUST' ei ole olemas."
        exit 2
    fi

    if ! [[ "$PÄEVI" =~ ^[0-9]+$ ]] || [[ "$PÄEVI" -lt 1 ]]; then
        viga "päevade arv peab olema positiivne täisarv (sain: '$PÄEVI')."
        exit 2
    fi
}

# -----------------------------------------------------------------------------
# kontrolli_ohutus() — normaliseerib tee ja kontrollib mustade nimekirja vastu
# Kasutab realpath-i, et trikitamist (../../..) ja sümbol-linke ei saaks
# -----------------------------------------------------------------------------
kontrolli_ohutus() {
    # eemalda lõpu "/"
    KAUST="${KAUST%/}"

    local kaust_real
    kaust_real="$(realpath "$KAUST")"

    for k in "${KEELATUD[@]}"; do
        # tühi $HOME väldib false-positive (kui HOME pole määratud)
        [[ -z "$k" ]] && continue
        if [[ "$kaust_real" == "$k" ]]; then
            viga "kaust '$kaust_real' on kaitstud keelatud nimekirja poolt."
            exit 3
        fi
    done

    # uuendame KAUST-t kanoonilise teega — kõik järgnev on selge
    KAUST="$kaust_real"
}

# -----------------------------------------------------------------------------
# loenda_failid() — prindib globaalmuutujatele FAILE_ARV ja SUURUS_MB
# Leiab failid -mtime +N alusel (muutmise aeg üle N päeva tagasi)
# -----------------------------------------------------------------------------
FAILE_ARV=0
SUURUS_MB=0

loenda_failid() {
    # NB! wc -l ei käsitle reavahetustega failinimesid korrektselt —
    # vt README "Teadaolevad puudused".
    FAILE_ARV=$(find "$KAUST" -type f -mtime +"$PÄEVI" | wc -l)

    if [[ "$FAILE_ARV" -eq 0 ]]; then
        return 0
    fi

    # Suuruse arvutus baitides → MB
    local suurus_baitides
    suurus_baitides=$(find "$KAUST" -type f -mtime +"$PÄEVI" -print0 \
        | xargs -0 du -bc 2>/dev/null \
        | tail -1 \
        | awk '{print $1}')
    SUURUS_MB=$(( suurus_baitides / 1024 / 1024 ))
}

# -----------------------------------------------------------------------------
# tee_dry_run() — näitab kuni 10 faili eelvaates, ei muuda midagi
# -----------------------------------------------------------------------------
tee_dry_run() {
    local arhiivinimi="$1"
    echo "DRY RUN — järgmist teeksin:"
    echo "  1. Arhiveeriks $FAILE_ARV faili → $arhiivinimi"
    echo "  2. Kustutaks originaalid ($SUURUS_MB MB)"
    echo ""
    echo "Eelvaade (kuni 10 faili):"
    find "$KAUST" -type f -mtime +"$PÄEVI" -print | head -10 | sed 's/^/  /'
    if [[ "$FAILE_ARV" -gt 10 ]]; then
        echo "  ... ja veel $((FAILE_ARV - 10)) faili"
    fi
}

# -----------------------------------------------------------------------------
# arhiveeri_ja_kustuta(arhiivinimi) — turvavõrk: kustutus AINULT pärast tar OK
# -----------------------------------------------------------------------------
arhiveeri_ja_kustuta() {
    local arhiivinimi="$1"

    echo "Arhiveerin: $arhiivinimi"

    # find -print0 + tar --null -T -  → talub tühikuid ja erisümboleid nimedes
    if ! find "$KAUST" -type f -mtime +"$PÄEVI" -print0 \
         | tar --null -czf "$arhiivinimi" -T -; then
        viga "arhiveerimine ebaõnnestus. Ei kustuta midagi."
        exit 4
    fi

    local arhiivi_suurus
    arhiivi_suurus=$(du -h "$arhiivinimi" | awk '{print $1}')
    echo "Arhiiv loodud ($arhiivi_suurus)."

    echo "Kustutan $FAILE_ARV faili..."
    find "$KAUST" -type f -mtime +"$PÄEVI" -delete

    echo "Valmis! Vabanes $SUURUS_MB MB."
}

# -----------------------------------------------------------------------------
# main() — programmijuht
# -----------------------------------------------------------------------------
main() {
    parsi_argumendid "$@"
    valideeri_sisend
    kontrolli_ohutus

    echo "Puhastus: $KAUST"
    echo "Vanusepiir: $PÄEVI päeva"

    loenda_failid

    if [[ "$FAILE_ARV" -eq 0 ]]; then
        echo "Ei leidnud vastavaid faile. Pole midagi teha."
        exit 0
    fi

    echo "Leidsin $FAILE_ARV faili ($SUURUS_MB MB)."

    local arhiivinimi
    arhiivinimi="arhiiv_$(date +%Y-%m-%d_%H%M%S).tar.gz"

    if $DRY_RUN; then
        tee_dry_run "$arhiivinimi"
        exit 0
    fi

    arhiveeri_ja_kustuta "$arhiivinimi"
}

main "$@"