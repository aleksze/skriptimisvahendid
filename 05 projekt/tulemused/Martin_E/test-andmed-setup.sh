#!/usr/bin/env bash
set -euo pipefail

# Test-andmete loomine Ülesanne C jaoks
# Loob ohutu testkausta ja sinna vanad + värsked failid

TESTDIR="/c/temp/test-puhastus"

echo "Loon testkausta: $TESTDIR"
mkdir -p "$TESTDIR"
cd "$TESTDIR"

echo "Loon 5 vana faili (10 päeva vanad)..."
for i in 1 2 3 4 5; do
    echo "Vana fail $i sisu" > "vana_$i.log"
    touch -d "10 days ago" "vana_$i.log"
done

echo "Loon 3 värsket faili..."
for i in 1 2 3; do
    echo "Värske fail $i" > "varske_$i.txt"
done

echo "Valmis. Kaustas on nüüd 5 vana ja 3 värsket faili."
ls -la
