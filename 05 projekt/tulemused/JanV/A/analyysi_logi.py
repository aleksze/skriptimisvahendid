

import argparse
import csv
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


# ---------------------------------------------------------------------------
# 1. Ühe rea parsimine
# ---------------------------------------------------------------------------

def parse_rida(rida: str) -> dict | None:
    """Parsib ühe logirea sõnastikuks. Vigase rea puhul tagastab None.

    Oodatav formaat:
      AJATEMPEL\\t[STAATUS]\\tSEVERITY\\tALLIKAS\\tSÕNUM[\\tVIGA]
    """
    osad = rida.strip().split("\t")

    if len(osad) < 5:
        return None  # liiga vähe välju

    ajatempel, staatus, severity, allikas, sõnum, *veateade = osad

    try:
        aeg = datetime.strptime(ajatempel, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None  # halb kuupäevaformaat

    return {
        "aeg":      aeg,
        "staatus":  staatus.strip("[]"),   # "[OK]" -> "OK"
        "severity": severity,
        "allikas":  allikas,
        "sõnum":    sõnum,
        "viga":     veateade[0] if veateade else None,
    }


# ---------------------------------------------------------------------------
# 2. Kogu faili lugemine
# ---------------------------------------------------------------------------

def loe_logi(tee: Path) -> list[dict]:
    """Loeb logifaili ja tagastab parsitud kirjete loendi.

    Vigased read jäetakse vahele — loendatakse ja hoiatatakse,
    aga skript ei katkesta.
    Tühja faili puhul tagastatakse tühi loend.
    """
    if not tee.exists():
        raise FileNotFoundError(f"Logifail puudub: {tee}")

    vigased = 0
    teated = []

    for rida in tee.read_text(encoding="utf-8").splitlines():
        if not rida.strip():
            continue  # tühi rida
        parsed = parse_rida(rida)
        if parsed:
            teated.append(parsed)
        else:
            vigased += 1

    if vigased:
        print(f"Hoiatus: {vigased} rida ei suutnud parsida")

    return teated


# ---------------------------------------------------------------------------
# 3. Analüüs
# ---------------------------------------------------------------------------

def analuusi(teated: list[dict]) -> dict:
    """Koondab teated päevade, raskusastmete ja allikate järgi.

    Tagastab sõnastiku kõigi statistikatega.
    Tühja sisendi puhul tagastatakse minimaalstruktuuri.
    """
    if not teated:
        return {
            "esimene": None, "viimane": None,
            "kokku": 0, "ebaõnnestumisi": 0,
            "paevad": {}, "allikad": Counter(), "severity": Counter(),
        }

    # defaultdict(lambda: Counter()) — iga uus päev saab automaatselt
    # tühja Counter-i, ei pea ise kontrollima kas võti on olemas
    paevad: dict = defaultdict(lambda: Counter())

    for t in teated:
        paev = t["aeg"].date()   # datetime -> date (ainult kuupäev)
        paevad[paev][t["severity"]] += 1
        paevad[paev]["_kokku"] += 1
        if t["staatus"] == "FAIL":
            paevad[paev]["_fail"] += 1

    return {
        "esimene":        min(t["aeg"] for t in teated).date(),
        "viimane":        max(t["aeg"] for t in teated).date(),
        "kokku":          len(teated),
        "ebaõnnestumisi": sum(1 for t in teated if t["staatus"] == "FAIL"),
        "paevad":         dict(paevad),
        "allikad":        Counter(t["allikas"] for t in teated),
        "severity":       Counter(t["severity"] for t in teated),
    }


# ---------------------------------------------------------------------------
# 4. Konsooli väljund
# ---------------------------------------------------------------------------

def prindi_kokkuvote(tulemus: dict) -> None:
    """Prindib analüüsi kokkuvõtte konsooli struktureeritult."""

    # Tühja logi käsitlemine
    if tulemus["kokku"] == 0:
        print("Logifail on tühi — midagi analüüsida pole.")
        return

    päevade_arv = (tulemus["viimane"] - tulemus["esimene"]).days + 1

    print(f"\nPeriood:       {tulemus['esimene']} kuni {tulemus['viimane']} ({päevade_arv} päeva)")
    print(f"Teadeid kokku: {tulemus['kokku']}")
    print(f"  ├─ õnnestus:      {tulemus['kokku'] - tulemus['ebaõnnestumisi']}")
    print(f"  └─ ebaõnnestus:   {tulemus['ebaõnnestumisi']}")

    print("\nRaskusaste:")
    for tase in ("Info", "Warning", "Critical"):
        arv = tulemus["severity"].get(tase, 0)
        print(f"  {tase:<10} {arv}")

    print("\nTop allikad:")
    for koht, (allikas, arv) in enumerate(tulemus["allikad"].most_common(), 1):
        print(f"  {koht}. {allikas} — {arv} teadet")

    print("\nCritical teated päeva lõikes:")
    paevad = tulemus["paevad"]
    max_cr = max((p.get("Critical", 0) for p in paevad.values()), default=0)

    # Skaleeritud ASCII-riba: iga täis-laius = max_cr Critical teadet
    # Valisin skaleeritud versiooni (mitte "iga ██ = 1"),
    # kuna see töötab ka suurte arvude puhul.
    for paev in sorted(paevad):
        arv = paevad[paev].get("Critical", 0)
        if max_cr > 0:
            pikkus = int(round(arv / max_cr * 10))
            riba = "██" * pikkus if pikkus else "-"
        else:
            riba = "-"
        print(f"  {paev}: {riba} ({arv})")


# ---------------------------------------------------------------------------
# 5. CSV salvestamine
# ---------------------------------------------------------------------------

def salvesta_csv(tulemus: dict, tee: Path) -> None:
    """Kirjutab päeva-statistika CSV-faili.

    Veerud: Päev, Teateid kokku, Info, Warning, Critical, Ebaõnnestunud
    """
    with open(tee, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Päev", "Teateid kokku", "Info", "Warning", "Critical", "Ebaõnnestunud"])

        # sorted() töötab date-objektidega loomulikult (ei vaja strfmt-i)
        for paev in sorted(tulemus["paevad"]):
            p = tulemus["paevad"][paev]
            w.writerow([
                paev,
                p.get("_kokku", 0),
                p.get("Info", 0),
                p.get("Warning", 0),
                p.get("Critical", 0),
                p.get("_fail", 0),
            ])


# ---------------------------------------------------------------------------
# 6. Peaprogramm
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Analüüsi teavituste logifaili")
    parser.add_argument(
        "logi",
        nargs="?",
        default="ps-alerts.log",
        help="Logifail (vaikimisi: ps-alerts.log)",
    )
    parser.add_argument(
        "--väljund",
        default="analyys_paevad.csv",
        help="CSV-väljundfail (vaikimisi: analyys_paevad.csv)",
    )
    args = parser.parse_args()

    logi_tee = Path(args.logi)
    csv_tee  = Path(args.väljund)

    try:
        teated = loe_logi(logi_tee)
    except FileNotFoundError as e:
        print(f"Viga: {e}")
        return

    tulemus = analuusi(teated)
    prindi_kokkuvote(tulemus)
    salvesta_csv(tulemus, csv_tee)
    print(f"\nCSV salvestatud: {csv_tee}")


# if __name__ == "__main__" tagab, et main() käivitatakse ainult siis,
# kui skripti käivitatakse otse — mitte kui keegi seda impordib moodulina.
if __name__ == "__main__":
    main()
