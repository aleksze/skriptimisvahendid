#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# puhasta.sh — Kaustade puhastus (Ülesanne C)
# Git Bash versioon (Windows)
# ---------------------------------------------

show_help() {
    cat <<EOF
Kasutamine:
  $0 <kaust> <päevad> [--dry-run]

Näide:
  $0 "/c/temp/test" 7

Valikud:
  --dry-run   Näitab, mida tehtaks, kuid ei arhiveeri ega kustuta
  --help      Näita abiinfot
EOF
}

# ---------------------------------------------
# Argumentide kontroll
# ---------------------------------------------
if [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# -lt 2 ]]; then
    echo "Viga: vaja kahte argumenti: <kaust> <päevad>" >&2
    exit 1
fi

TARGET_DIR="$1"
DAYS="$2"
DRY_RUN="${3:-}"

# Kontroll: päevade arv peab olema positiivne täisarv
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    echo "Viga: päevade arv peab olema positiivne täisarv." >&2
    exit 1
fi

# Kontroll: kaust peab eksisteerima
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Viga: kausta '$TARGET_DIR' ei eksisteeri." >&2
    exit 1
fi

# ---------------------------------------------
# Must nimekiri (Git Bash realpath alternatiiv)
# ---------------------------------------------
ABS_DIR="$(cd "$TARGET_DIR" && pwd -W 2>/dev/null || pwd)"

BLOCKED=(
    "C:\\"
    "C:\\Windows"
    "C:\\Users"
    "$HOME"
)

for forbidden in "${BLOCKED[@]}"; do
    if [[ "$ABS_DIR" == "$forbidden" ]]; then
        echo "Viga: kausta '$ABS_DIR' puhastamine on keelatud (ohtlik)." >&2
        exit 2
    fi
done

# ---------------------------------------------
# Failide leidmine (Git Bashile sobiv)
# ---------------------------------------------
echo "Puhastus: $ABS_DIR"
echo "Vanusepiir: $DAYS päeva"

# Leiame failid
FILES=()
while IFS= read -r f; do
    FILES+=("$f")
done < <(find "$ABS_DIR" -type f -mtime +"$DAYS")

FILE_COUNT="${#FILES[@]}"

if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "Pole midagi puhastada. Väljun."
    exit 0
fi

# Arvuta kogumaht (Git Bash du -h ei anna total)
TOTAL_SIZE=0
for f in "${FILES[@]}"; do
    SIZE=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f")
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
done

# Inimloetav suurus
HUMAN_SIZE=$(awk -v s="$TOTAL_SIZE" 'BEGIN {
    split("B KB MB GB TB", u);
    for(i=1; s>=1024 && i<5; i++) s/=1024;
    printf "%.1f %s", s, u[i];
}')

echo "Leidsin $FILE_COUNT faili ($HUMAN_SIZE)."

# ---------------------------------------------
# Dry-run
# ---------------------------------------------
if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo ""
    echo "DRY-RUN režiim — ei arhiveeri ega kustuta."
    printf "%s\n" "${FILES[@]}"
    exit 0
fi

# ---------------------------------------------
# Arhiveerimine (Git Bashile sobiv)
# ---------------------------------------------
TS=$(date +"%Y-%m-%d_%H%M%S")
ARCHIVE="arhiiv_${TS}.tar.gz"

echo "Arhiveerin: $ARCHIVE"

tar -czf "$ARCHIVE" "${FILES[@]}"

echo "Arhiiv loodud ($(du -h "$ARCHIVE" | awk '{print $1}'))."

# ---------------------------------------------
# Kustutamine
# ---------------------------------------------
echo "Kustutan $FILE_COUNT faili..."

for f in "${FILES[@]}"; do
    rm -f -- "$f"
done

echo "Valmis! Vabanes $HUMAN_SIZE."
exit 0
