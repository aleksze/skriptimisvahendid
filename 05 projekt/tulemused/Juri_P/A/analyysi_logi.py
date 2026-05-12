import argparse
import csv
from pathlib import Path
from datetime import datetime
from collections import Counter, defaultdict


def parse_rida(rida: str) -> dict | None:
    """Parsib ühe logirea sõnastikuks. Vigase rea puhul tagastab None."""
    osad = rida.strip().split("\t")

    if len(osad) < 5:
        return None

    ajatempel, staatus, severity, allikas, sonum, *veateade = osad

    try:
        aeg = datetime.strptime(ajatempel, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None

    return {
        "aeg": aeg,
        "staatus": staatus.strip("[]"),
        "severity": severity,
        "allikas": allikas,
        "sonum": sonum,
        "viga": veateade[0] if veateade else None,
    }


def loe_logi(tee: Path) -> list[dict]:
    """Loeb logifaili ja tagastab parsed teated."""
    if not tee.exists():
        raise FileNotFoundError(f"Logifail puudub: {tee}")

    vigased = 0
    teated = []

    for rida in tee.read_text(encoding="utf-8").splitlines():
        if not rida.strip():
            continue

        parsed = parse_rida(rida)
        if parsed:
            teated.append(parsed)
        else:
            vigased += 1

    if vigased:
        print(f"Hoiatus: {vigased} vigast rida jäeti vahele")

    return teated


def analuusi(teated: list[dict]) -> dict:
    """Analüüsib teated ja tagastab statistika."""
    if not teated:
        return {
            "esimene": None,
            "viimane": None,
            "kokku": 0,
            "paevad": {},
            "allikad": Counter(),
            "severity": Counter(),
            "ebaõnnestumisi": 0,
        }

    paevad = defaultdict(lambda: Counter())

    for t in teated:
        paev = t["aeg"].date()

        paevad[paev][t["severity"]] += 1
        paevad[paev]["_kokku"] += 1

        if t["staatus"] == "FAIL":
            paevad[paev]["_fail"] += 1

    return {
        "esimene": min(t["aeg"] for t in teated).date(),
        "viimane": max(t["aeg"] for t in teated).date(),
        "kokku": len(teated),
        "paevad": dict(paevad),
        "allikad": Counter(t["allikas"] for t in teated),
        "severity": Counter(t["severity"] for t in teated),
        "ebaõnnestumisi": sum(1 for t in teated if t["staatus"] == "FAIL"),
    }


def ascii_riba(arv: int) -> str:
    """Lihtne ASCII-graafik."""
    return "██" * arv if arv else "-"


def prindi_kokkuvote(t: dict) -> None:
    """Prindib konsooli kokkuvõtte."""
    if t["kokku"] == 0:
        print("Logifail on tühi.")
        return

    paevade_arv = (t["viimane"] - t["esimene"]).days + 1

    print(f"Periood:      {t['esimene']} kuni {t['viimane']} ({paevade_arv} päeva)")
    print(f"Teateid kokku: {t['kokku']}")
    print(f"  ├─ õnnestus:  {t['kokku'] - t['ebaõnnestumisi']}")
    print(f"  └─ ebaõnnestus: {t['ebaõnnestumisi']}\n")

    print("Raskusaste:")
    for sev in ["Info", "Warning", "Critical"]:
        print(f"  {sev}: {t['severity'].get(sev, 0)}")

    print("\nTop allikad:")
    for i, (allikas, arv) in enumerate(t["allikad"].most_common(3), start=1):
        print(f"  {i}. {allikas:<10} — {arv} teadet")

    print("\nCritical teated päeva lõikes:")
    for paev in sorted(t["paevad"]):
        arv = t["paevad"][paev].get("Critical", 0)
        print(f"  {paev}: {ascii_riba(arv)} ({arv})")


def salvesta_csv(t: dict, tee: Path) -> None:
    """Salvestab tulemuse CSV faili."""
    with open(tee, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)

        w.writerow(["Päev", "Teateid kokku", "Info", "Warning", "Critical", "Ebaõnnestunud"])

        for paev in sorted(t["paevad"]):
            p = t["paevad"][paev]
            w.writerow([
                paev,
                p.get("_kokku", 0),
                p.get("Info", 0),
                p.get("Warning", 0),
                p.get("Critical", 0),
                p.get("_fail", 0),
            ])


def main():
    parser = argparse.ArgumentParser(description="Analüüsi logifaili")
    parser.add_argument("logi", nargs="?", default="naidis_ps-alerts.log",
                        help="Logifail (vaikimisi naidis_ps-alerts.log)")
    parser.add_argument("--väljund", default="analyys_paevad.csv",
                        help="CSV väljundfail")

    args = parser.parse_args()

    teated = loe_logi(Path(args.logi))
    tulemus = analuusi(teated)

    prindi_kokkuvote(tulemus)
    salvesta_csv(tulemus, Path(args.väljund))

    print(f"\nCSV salvestatud: {args.väljund}")


if __name__ == "__main__":
    main()