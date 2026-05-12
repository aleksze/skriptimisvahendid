#!/usr/bin/env python3
"""
Logianalüüsi skript (Ülesanne A)
Autor: Martin E
Kursus: KIT-24

Loeb ps-alerts.log formaadis logifaili ja koostab:
 - konsooli kokkuvõtte
 - CSV faili päevade kaupa
"""

from pathlib import Path
from datetime import datetime
from collections import defaultdict, Counter
import csv
import argparse


# ---------------------------------------------------------
# 1. PARSI ÜKS RIDA
# ---------------------------------------------------------
def parse_rida(rida: str):
    """
    Parsib ühe logirea.
    Tagastab dict või None, kui rida on vigane.
    Formaat:
    AJATEMPEL [STAATUS] SEVERITY ALLIKAS SÕNUM [VIGA]
    """
    try:
        osad = rida.strip().split()
        if len(osad) < 5:
            return None

        # Esimesed 4 välja on fikseeritud
        ajatempel_raw = f"{osad[0]} {osad[1]}"
        staatus_raw = osad[2]
        severity = osad[3]
        allikas = osad[4]
        ylejaanud = osad[5:]

        aeg = datetime.strptime(ajatempel_raw, "%Y-%m-%d %H:%M:%S")
        staatus = staatus_raw.strip("[]")
        sonum = " ".join(ylejaanud).strip()

        return {
            "aeg": aeg,
            "staatus": staatus,
            "severity": severity,
            "allikas": allikas,
            "sonum": sonum
        }

    except Exception:
        return None



# ---------------------------------------------------------
# 2. LOE FAIL
# ---------------------------------------------------------
def loe_logi(path: Path):
    """
    Loeb logifaili ja tagastab listi parsetud teadetest.
    Vigased read logitakse ja vahele jäetakse.
    """
    if not path.exists():
        print(f"Logifaili ei leitud: {path}")
        return []

    tulemused = []
    vigased = 0

    for rida in path.read_text(encoding="utf-8").splitlines():
        parsed = parse_rida(rida)
        if parsed:
            tulemused.append(parsed)
        else:
            vigased += 1

    if vigased > 0:
        print(f"⚠ Hoiatus: {vigased} vigast rida jäeti vahele.")

    return tulemused


# ---------------------------------------------------------
# 3. ANALÜÜS
# ---------------------------------------------------------
def analuusi(teated):
    """
    Tagastab:
      - päevade kaupa Counterid
      - allikate Counter
      - severity Counter
    """
    paevad = defaultdict(Counter)
    allikad = Counter()
    severity = Counter()

    for t in teated:
        paev = t["aeg"].date()
        paevad[paev]["kokku"] += 1
        paevad[paev][t["severity"]] += 1
        if t["staatus"] != "OK":
            paevad[paev]["Ebaõnnestunud"] += 1

        allikad[t["allikas"]] += 1
        severity[t["severity"]] += 1

    return paevad, allikad, severity


# ---------------------------------------------------------
# 4. KONSOOLI VÄLJUND
# ---------------------------------------------------------
def prindi_kokkuvote(teated, paevad, allikad, severity):
    if not teated:
        print("Logifail on tühi — pole midagi analüüsida.")
        return

    kuupaevad = sorted(paevad.keys())
    algus = kuupaevad[0]
    lopp = kuupaevad[-1]

    print()
    print(f"Periood:      {algus} kuni {lopp} ({len(kuupaevad)} päeva)")
    print(f"Teateid kokku: {len(teated)}")

    ok = sum(1 for t in teated if t["staatus"] == "OK")
    fail = len(teated) - ok

    print(f"  ├─ õnnestus:  {ok}")
    print(f"  └─ ebaõnnestus: {fail}")
    print()

    print("Raskusaste:")
    for sev in ["Info", "Warning", "Critical"]:
        print(f"  {sev}: {severity.get(sev, 0)}")
    print()

    print("Top allikad:")
    for i, (allikas, arv) in enumerate(allikad.most_common(), start=1):
        print(f"  {i}. {allikas:<10} — {arv} teadet")
    print()

    print("Critical teated päeva lõikes:")
    for paev in kuupaevad:
        arv = paevad[paev].get("Critical", 0)
        graaf = "█" * arv if arv > 0 else "-"
        print(f"  {paev}: {graaf} ({arv})")
    print()


# ---------------------------------------------------------
# 5. CSV VÄLJUND
# ---------------------------------------------------------
def kirjuta_csv(paevad, output: Path):
    with output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Päev", "Teateid kokku", "Info", "Warning", "Critical", "Ebaõnnestunud"])

        for paev in sorted(paevad.keys()):
            c = paevad[paev]
            writer.writerow([
                paev,
                c.get("kokku", 0),
                c.get("Info", 0),
                c.get("Warning", 0),
                c.get("Critical", 0),
                c.get("Ebaõnnestunud", 0)
            ])


# ---------------------------------------------------------
# 6. ARGPARSE + MAIN
# ---------------------------------------------------------
def main():
    print("Skript käivitus!")  # ← aitab sul näha, et skript töötab

    parser = argparse.ArgumentParser(description="Logianalüüsi skript (Ülesanne A)")
    parser.add_argument("--input", default="ps-alerts.log", help="Sisendi logifail")
    parser.add_argument("--output", default="analyys_paevad.csv", help="CSV väljundfail")
    args = parser.parse_args()

    logifail = Path(args.input)
    csvfail = Path(args.output)

    teated = loe_logi(logifail)
    paevad, allikad, severity = analuusi(teated)

    prindi_kokkuvote(teated, paevad, allikad, severity)
    kirjuta_csv(paevad, csvfail)

    print(f"CSV salvestatud: {csvfail}")


if __name__ == "__main__":
    main()