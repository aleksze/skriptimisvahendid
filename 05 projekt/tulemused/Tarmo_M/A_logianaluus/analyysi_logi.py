#!/usr/bin/env python3
"""
Logianalüüsi skript — KIT-24 Iseseisev töö, ülesanne A.
Autor: Tarmo M.

Loeb teavituste logifaili ja koostab raporti:
  - kokkuvõte konsoolis (kogused, raskusastmed, top allikad, ASCII-graafik)
  - CSV päevade lõikes

Toetatud rea-formaat (Saada-Teavitus.psm1 väljund):
    YYYY-MM-DD HH:MM:SS [STAATUS] SEVERITY | ALLIKAS | SÕNUM [| VIGA]
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

# --------------------------------------------------------------------------- #
# Parsimine
# --------------------------------------------------------------------------- #

# Näide: "2026-04-21 11:31:35 [OK]   Critical | DESKTOP-05P8344 | sõnum | viga"
RIDA_RE = re.compile(
    r"^(?P<aeg>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+"
    r"\[(?P<staatus>[^\]]+)\]\s+"
    r"(?P<severity>\S+)\s*\|\s*"
    r"(?P<allikas>[^|]+?)\s*\|\s*"
    r"(?P<sõnum>.*)$"
)


def parse_rida(rida: str) -> dict | None:
    """Parsib ühe logirea sõnastikuks. Vigase rea puhul tagastab None."""
    m = RIDA_RE.match(rida.rstrip("\r\n"))
    if not m:
        return None
    try:
        aeg = datetime.strptime(m.group("aeg"), "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None

    sõnum_osa = m.group("sõnum").strip()
    # Kui sõnumis on veel "|" — viimane osa on viga
    if " | " in sõnum_osa:
        sõnum, viga = sõnum_osa.rsplit(" | ", 1)
        sõnum, viga = sõnum.strip(), viga.strip()
    else:
        sõnum, viga = sõnum_osa, None

    return {
        "aeg": aeg,
        "staatus": m.group("staatus").strip(),
        "severity": m.group("severity").strip(),
        "allikas": m.group("allikas").strip(),
        "sõnum": sõnum,
        "viga": viga,
    }


def _loe_tekst(tee: Path) -> str:
    """Loeb faili, proovib UTF-8 (BOM-iga), siis UTF-16, siis cp1257."""
    raw = tee.read_bytes()
    # BOM-i tuvastus
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    if raw[:3] == b"\xef\xbb\xbf":
        return raw.decode("utf-8-sig")
    for enc in ("utf-8", "utf-16", "cp1257"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def loe_logi(tee: Path) -> list[dict]:
    """Loeb logifaili ja tagastab parsitud teadete listi."""
    if not tee.exists():
        raise FileNotFoundError(f"Logifail puudub: {tee}")

    teated: list[dict] = []
    vigaseid = 0
    sisu = _loe_tekst(tee)

    # Mõned read sisaldavad reavahetust sõnumis (nt failitee järgmisel real).
    # Liidame kokku read, mis ei alga ajatempliga.
    ajatempel_re = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}")
    puhver: list[str] = []
    read: list[str] = []
    for rida in sisu.splitlines():
        if ajatempel_re.match(rida):
            if puhver:
                read.append(" ".join(puhver))
            puhver = [rida]
        else:
            if rida.strip() and puhver:
                puhver.append(rida.strip())
    if puhver:
        read.append(" ".join(puhver))

    for nr, rida in enumerate(read, start=1):
        if not rida.strip():
            continue
        parsed = parse_rida(rida)
        if parsed:
            teated.append(parsed)
        else:
            vigaseid += 1
            print(f"  hoiatus: rida {nr} ei sobi formaati — jäetud vahele",
                  file=sys.stderr)

    if vigaseid:
        print(f"Kokku vigased read: {vigaseid}\n", file=sys.stderr)
    return teated


# --------------------------------------------------------------------------- #
# Analüüs
# --------------------------------------------------------------------------- #

def analuusi(teated: list[dict]) -> dict:
    if not teated:
        return {
            "tühi": True, "kokku": 0, "esimene": None, "viimane": None,
            "paevad": {}, "allikad": Counter(), "severity": Counter(),
            "ebaõnnestumisi": 0,
        }
    paevad: dict = defaultdict(Counter)
    for t in teated:
        paev = t["aeg"].date()
        paevad[paev][t["severity"]] += 1
        paevad[paev]["_kokku"] += 1
        if t["staatus"] == "FAIL":
            paevad[paev]["_fail"] += 1
    return {
        "tühi": False,
        "esimene": min(t["aeg"] for t in teated).date(),
        "viimane": max(t["aeg"] for t in teated).date(),
        "kokku": len(teated),
        "paevad": dict(paevad),
        "allikad": Counter(t["allikas"] for t in teated),
        "severity": Counter(t["severity"] for t in teated),
        "ebaõnnestumisi": sum(1 for t in teated if t["staatus"] == "FAIL"),
    }


# --------------------------------------------------------------------------- #
# Väljund
# --------------------------------------------------------------------------- #

def _ascii_riba(arv: int, max_arv: int, laius: int = 20) -> str:
    if max_arv <= 0 or arv <= 0:
        return "-"
    pikkus = max(1, int(round(arv / max_arv * laius)))
    return "█" * pikkus + f" ({arv})"


def prindi_kokkuvote(t: dict) -> None:
    if t["tühi"]:
        print("Logifail on tühi või ei sisalda ühtki kehtivat rida.")
        return
    paevi = (t["viimane"] - t["esimene"]).days + 1
    print(f"Periood:       {t['esimene']} kuni {t['viimane']} ({paevi} päeva)")
    print(f"Teadeid kokku: {t['kokku']}")
    print(f"  ├─ õnnestus:    {t['kokku'] - t['ebaõnnestumisi']}")
    print(f"  └─ ebaõnnestus: {t['ebaõnnestumisi']}")
    print("\nRaskusaste:")
    for sev in ("Info", "Warning", "Critical"):
        print(f"  {sev:<9} {t['severity'].get(sev, 0)}")
    print("\nTop allikad:")
    for i, (allikas, n) in enumerate(t["allikad"].most_common(5), start=1):
        print(f"  {i}. {allikas:<15} — {n} teadet")
    print("\nCritical teated päeva lõikes:")
    crit_kaupa = {p: andmed.get("Critical", 0) for p, andmed in t["paevad"].items()}
    max_crit = max(crit_kaupa.values()) if crit_kaupa else 0
    for paev in sorted(crit_kaupa):
        print(f"  {paev}: {_ascii_riba(crit_kaupa[paev], max_crit)}")


def salvesta_csv(t: dict, tee: Path) -> None:
    with tee.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Päev", "Teateid kokku", "Info", "Warning",
                    "Critical", "Ebaõnnestunud"])
        for paev in sorted(t.get("paevad", {})):
            p = t["paevad"][paev]
            w.writerow([
                paev.isoformat(),
                p.get("_kokku", 0),
                p.get("Info", 0),
                p.get("Warning", 0),
                p.get("Critical", 0),
                p.get("_fail", 0),
            ])


# --------------------------------------------------------------------------- #
# Käivitus
# --------------------------------------------------------------------------- #

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analüüsib teavituste logifaili ja koostab raporti."
    )
    parser.add_argument("logi", nargs="?", default="ps-alerts.log",
                        help="Logifaili tee (vaikimisi: ps-alerts.log)")
    parser.add_argument("--väljund", "-o", default="analyys_paevad.csv",
                        help="CSV-väljundfail (vaikimisi: analyys_paevad.csv)")
    args = parser.parse_args()

    try:
        teated = loe_logi(Path(args.logi))
    except FileNotFoundError as e:
        print(f"Viga: {e}", file=sys.stderr)
        return 2

    tulemus = analuusi(teated)
    prindi_kokkuvote(tulemus)
    salvesta_csv(tulemus, Path(args.väljund))
    print(f"\nCSV salvestatud: {args.väljund}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
