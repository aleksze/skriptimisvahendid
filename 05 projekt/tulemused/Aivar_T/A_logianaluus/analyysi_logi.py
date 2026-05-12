import argparse
import csv
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


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
    """Loeb logifaili, parsib read ja jätab vigased read vahele."""
    if not tee.exists():
        raise FileNotFoundError(f"Logifail puudub: {tee}")

    vigased = 0
    teated = []

    for rida in tee.read_text(encoding="utf-8").splitlines():
        if not rida.strip():
            continue

        parsed = parse_rida(rida)
        if parsed is None:
            vigased += 1
            continue

        teated.append(parsed)

    if vigased:
        print(f"Hoiatus: {vigased} rida ei suutnud parsida")

    return teated


def analuusi(teated: list[dict]) -> dict:
    """Koostab loetud teadetest kokkuvõtte päevade, allikate ja raskusastmete lõikes."""
    if not teated:
        return {
            "esimene": None,
            "viimane": None,
            "kokku": 0,
            "paevad": {},
            "allikad": Counter(),
            "severity": Counter(),
            "ebaonnestumisi": 0,
            "onnestus": 0,
        }

    paevad = defaultdict(Counter)

    for teade in teated:
        paev = teade["aeg"].date()
        paevad[paev]["_kokku"] += 1
        paevad[paev][teade["severity"]] += 1

        if teade["staatus"] == "FAIL":
            paevad[paev]["_fail"] += 1

    return {
        "esimene": min(t["aeg"] for t in teated).date(),
        "viimane": max(t["aeg"] for t in teated).date(),
        "kokku": len(teated),
        "paevad": dict(paevad),
        "allikad": Counter(t["allikas"] for t in teated),
        "severity": Counter(t["severity"] for t in teated),
        "ebaonnestumisi": sum(1 for t in teated if t["staatus"] == "FAIL"),
        "onnestus": sum(1 for t in teated if t["staatus"] == "OK"),
    }


def prindi_kokkuvote(tulemus: dict) -> None:
    """Prindib analüüsi tulemuse loetava kokkuvõttena konsooli."""
    if tulemus["kokku"] == 0:
        print("Logifail on tühi või sobivaid ridu ei leitud.")
        return

    paevade_arv = (tulemus["viimane"] - tulemus["esimene"]).days + 1

    print(f"Periood:      {tulemus['esimene']} kuni {tulemus['viimane']} ({paevade_arv} päeva)")
    print(f"Teateid kokku: {tulemus['kokku']}")
    print(f"  ├─ õnnestus:  {tulemus['onnestus']}")
    print(f"  └─ ebaõnnestus: {tulemus['ebaonnestumisi']}")
    print()
    print("Raskusaste:")
    print(f"  Info:     {tulemus['severity'].get('Info', 0)}")
    print(f"  Warning:  {tulemus['severity'].get('Warning', 0)}")
    print(f"  Critical: {tulemus['severity'].get('Critical', 0)}")
    print()
    print("Top allikad:")

    for koht, (allikas, arv) in enumerate(tulemus["allikad"].most_common(3), start=1):
        sona = "teadet" if arv != 1 else "teade"
        print(f"  {koht}. {allikas} — {arv} {sona}")

    print()
    print("Critical teated päeva lõikes:")

    for paev in sorted(tulemus["paevad"]):
        arv = tulemus["paevad"][paev].get("Critical", 0)
        riba = "██" * arv if arv else "-"
        print(f"  {paev}: {riba} ({arv})")


def salvesta_csv(tulemus: dict, tee: Path) -> None:
    """Salvestab päevade lõikes kokkuvõtte CSV faili."""
    with tee.open("w", newline="", encoding="utf-8") as fail:
        writer = csv.writer(fail)
        writer.writerow(["Päev", "Teateid kokku", "Info", "Warning", "Critical", "Ebaõnnestunud"])

        for paev in sorted(tulemus["paevad"]):
            paeva_andmed = tulemus["paevad"][paev]
            writer.writerow([
                paev,
                paeva_andmed.get("_kokku", 0),
                paeva_andmed.get("Info", 0),
                paeva_andmed.get("Warning", 0),
                paeva_andmed.get("Critical", 0),
                paeva_andmed.get("_fail", 0),
            ])


def main() -> None:
    """Loeb käsurea argumendid, analüüsib logi ja salvestab CSV väljundi."""
    parser = argparse.ArgumentParser(description="Analüüsi teavituste logifaili")
    parser.add_argument(
        "logi",
        nargs="?",
        default="näidis_ps-alerts.log",
        help="Logifail (vaikimisi näidis_ps-alerts.log)",
    )
    parser.add_argument(
        "--valjund",
        default="analyys_paevad.csv",
        help="CSV-väljundfail (vaikimisi analyys_paevad.csv)",
    )
    args = parser.parse_args()

    teated = loe_logi(Path(args.logi))
    tulemus = analuusi(teated)

    prindi_kokkuvote(tulemus)
    salvesta_csv(tulemus, Path(args.valjund))

    print()
    print(f"CSV salvestatud: {args.valjund}")


if __name__ == "__main__":
    main()