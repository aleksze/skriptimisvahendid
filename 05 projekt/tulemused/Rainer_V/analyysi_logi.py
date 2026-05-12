import argparse
from pathlib import Path
from datetime import datetime
from collections import Counter, defaultdict
import csv


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
    """Loeb logifaili ja tagastab parsitud teadete listi."""
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
        print(f"Hoiatus: {vigased} rida ei suutnud parsida")

    return teated


def analuusi(teated: list[dict]) -> dict:
    """Analüüsib teadete listi ja tagastab kokkuvõtte."""
    if not teated:
        return {"periood": None, "kokku": 0, "paevad": {}}

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
        "ebaonnestumisi": sum(1 for t in teated if t["staatus"] == "FAIL"),
    }


def prindi_kokkuvote(tulemus: dict) -> None:
    """Prindib konsooli kokkuvõtte."""
    if not tulemus["kokku"]:
        print("Logifail on tühi — teated puuduvad.")
        return

    paevade_arv = (tulemus["viimane"] - tulemus["esimene"]).days + 1

    print(f"Periood:       {tulemus['esimene']} kuni {tulemus['viimane']} ({paevade_arv} päeva)")
    print(f"Teadeid kokku: {tulemus['kokku']}")
    print(f"  ├─ õnnestus:     {tulemus['kokku'] - tulemus['ebaonnestumisi']}")
    print(f"  └─ ebaõnnestus:  {tulemus['ebaonnestumisi']}")
    print()

    print("Raskusaste:")
    for sev in ["Info", "Warning", "Critical"]:
        print(f"  {sev:10} {tulemus['severity'].get(sev, 0)}")
    print()

    print("Top allikad:")
    for i, (allikas, arv) in enumerate(tulemus["allikad"].most_common(5), 1):
        print(f"  {i}. {allikas:15} — {arv} teadet")
    print()

    print("Critical teated päeva lõikes:")
    for paev in sorted(tulemus["paevad"]):
        arv = tulemus["paevad"][paev].get("Critical", 0)
        riba = "██" * arv if arv else "-"
        print(f"  {paev}: {riba} ({arv})")


def salvesta_csv(tulemus: dict, tee: Path) -> None:
    """Salvestab päevade kokkuvõtte CSV-faili."""
    with open(tee, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Päev", "Teateid kokku", "Info", "Warning", "Critical", "Ebaõnnestunud"])

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


def main():
    parser = argparse.ArgumentParser(description="Analüüsi teavituste logifaili")
    parser.add_argument("logi", nargs="?", default="ps-alerts.log",
                        help="Logifail (vaikimisi ps-alerts.log)")
    parser.add_argument("--väljund", default="analyys_paevad.csv",
                        help="CSV-väljundfail")
    args = parser.parse_args()

    teated = loe_logi(Path(args.logi))
    tulemus = analuusi(teated)
    prindi_kokkuvote(tulemus)
    salvesta_csv(tulemus, Path(args.väljund))
    print(f"\nCSV salvestatud: {args.väljund}")


if __name__ == "__main__":
    main()
