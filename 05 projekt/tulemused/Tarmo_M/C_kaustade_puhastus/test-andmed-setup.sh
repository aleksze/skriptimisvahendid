#!/bin/bash
# =============================================================================
# test-andmed-setup.sh — loob ohutu test-kausta puhasta.sh katsetamiseks
# Autor: Tarmo M
#
# Loob /tmp/test-puhastus, paneb sinna 5 "vana" faili (10 päeva tagasi)
# ja 3 värsket faili. Pärast saad jooksutada:
#   ./puhasta.sh /tmp/test-puhastus 7 --dry-run
# =============================================================================

set -euo pipefail

KAUST="/tmp/test-puhastus"

echo "Loon test-kausta: $KAUST"
mkdir -p "$KAUST"

# Tühjenda vanad katsed (et test oleks korratav)
rm -f "$KAUST"/vana_*.log "$KAUST"/varske_*.txt

# 5 "vana" faili — muutmise aeg 10 päeva tagasi
for i in 1 2 3 4 5; do
    echo "Vana fail $i sisu — peaks puhastusel kaduma." > "$KAUST/vana_$i.log"
    touch -d "10 days ago" "$KAUST/vana_$i.log"
done

# 3 värsket faili — peaksid alles jääma
for i in 1 2 3; do
    echo "Värske fail $i — peaks alles jääma." > "$KAUST/varske_$i.txt"
done

echo ""
echo "Test-kaust valmis. Sisu:"
ls -la "$KAUST"
echo ""
echo "Proovi nüüd:"
echo "  ./puhasta.sh $KAUST 7 --dry-run     # eelvaade, ei muuda midagi"
echo "  ./puhasta.sh $KAUST 7               # päris jooks (arhiveerib + kustutab)"
