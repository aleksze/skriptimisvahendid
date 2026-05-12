import argparse
import getpass
import json
import platform
import socket
from datetime import datetime, timezone
from pathlib import Path

import psutil


def kogu_host() -> dict:
    """Tagastab hosti, kasutaja ja Pythoni versiooni info."""
    return {
        "host": socket.gethostname(),
        "kasutaja": getpass.getuser(),
        "python": platform.python_version(),
    }


def kogu_os() -> dict:
    """Tagastab operatsioonisüsteemi info."""
    system = platform.system()
    os_nimed = {
        "Darwin": "macOS",
        "Linux": "Linux",
        "Windows": "Windows",
    }

    return {
        "süsteem": os_nimed.get(system, system or "Teadmata"),
        "versioon": platform.version() or "Teadmata",
        "release": platform.release() or "Teadmata",
        "arhitektuur": platform.architecture()[0] or "Teadmata",
        "masina_tüüp": platform.machine() or "Teadmata",
    }


def kogu_cpu() -> dict:
    """Tagastab CPU info."""
    mudel = platform.processor()

    if not mudel and platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo", encoding="utf-8") as fail:
                for rida in fail:
                    if rida.startswith("model name"):
                        mudel = rida.split(":", 1)[1].strip()
                        break
        except Exception:
            mudel = "Teadmata"

    return {
        "mudel": mudel or "Teadmata",
        "südamikud_füüsilised": psutil.cpu_count(logical=False) or "Teadmata",
        "südamikud_loogilised": psutil.cpu_count(logical=True) or "Teadmata",
        "kasutus_protsent": psutil.cpu_percent(interval=1),
    }


def kogu_malu() -> dict:
    """Tagastab mäluinfo gigabaitides."""
    m = psutil.virtual_memory()

    return {
        "kokku_gb": round(m.total / (1024**3), 2),
        "kasutuses_gb": round(m.used / (1024**3), 2),
        "vaba_gb": round(m.available / (1024**3), 2),
        "kasutus_protsent": m.percent,
    }


def kogu_kettad() -> list[dict]:
    """Tagastab ketaste info."""
    kettad = []

    for osa in psutil.disk_partitions(all=False):
        try:
            kasutus = psutil.disk_usage(osa.mountpoint)
        except (PermissionError, OSError):
            continue

        kettad.append({
            "haakepunkt": osa.mountpoint,
            "seade": osa.device,
            "failisüsteem": osa.fstype or "Teadmata",
            "kokku_gb": round(kasutus.total / (1024**3), 2),
            "vaba_gb": round(kasutus.free / (1024**3), 2),
            "kasutatud_gb": round(kasutus.used / (1024**3), 2),
            "kasutus_protsent": kasutus.percent,
        })

    return kettad


def kogu_vork() -> list[dict]:
    """Tagastab võrguliideste info, ka ühendamata liidesed."""
    kaardid = []
    aadressid = psutil.net_if_addrs()
    olekud = psutil.net_if_stats()

    for nimi, adrlist in aadressid.items():
        ipv4 = next(
            (
                a.address
                for a in adrlist
                if a.family == socket.AF_INET and not a.address.startswith("127.")
            ),
            None,
        )

        stat = olekud.get(nimi)
        on_uleval = stat.isup if stat else False

        kaardid.append({
            "nimi": nimi,
            "ipv4": ipv4,
            "ühendatud": on_uleval,
        })

    return kaardid


def kogu_inventuur() -> dict:
    """Koostab kogu inventuuri üheks sõnastikuks."""
    return {
        "ajamäär": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        **kogu_host(),
        "os": kogu_os(),
        "cpu": kogu_cpu(),
        "mälu": kogu_malu(),
        "kettad": kogu_kettad(),
        "võrk": kogu_vork(),
    }


def prindi_kokkuvote(inventuur: dict, failinimi: Path) -> None:
    """Prindib inventuuri lühikokkuvõtte konsooli."""
    print("=== Süsteemi inventuur ===")
    print(f"Host:        {inventuur['host']}")
    print(f"Kasutaja:    {inventuur['kasutaja']}")
    print(f"OS:          {inventuur['os']['süsteem']} {inventuur['os']['release']} ({inventuur['os']['versioon']})")
    print(f"Python:      {inventuur['python']}")
    print()
    print(f"CPU:         {inventuur['cpu']['mudel']}")
    print(
        f"Südamikke:   {inventuur['cpu']['südamikud_füüsilised']} "
        f"({inventuur['cpu']['südamikud_loogilised']} loogilist)"
    )
    print(
        f"RAM:         {inventuur['mälu']['kokku_gb']} GB "
        f"(kasutuses {inventuur['mälu']['kasutus_protsent']}%)"
    )
    print()
    print("Kettad:")
    if inventuur["kettad"]:
        for ketas in inventuur["kettad"]:
            vaba_protsent = round(100 - ketas["kasutus_protsent"], 1)
            print(
                f"  {ketas['haakepunkt']:<6} "
                f"Total: {ketas['kokku_gb']} GB  "
                f"Free: {ketas['vaba_gb']} GB  "
                f"({vaba_protsent}% vaba)"
            )
    else:
        print("  Teadmata")

    print("Võrgukaardid:")
    if inventuur["võrk"]:
        for kaart in inventuur["võrk"]:
            if kaart["ühendatud"] and kaart["ipv4"]:
                print(f"  {kaart['nimi']:<16} {kaart['ipv4']}")
            elif kaart["ühendatud"]:
                print(f"  {kaart['nimi']:<16} (ühendatud, IPv4 puudub)")
            else:
                print(f"  {kaart['nimi']:<16} (ühendamata)")
    else:
        print("  Teadmata")

    print()
    print(f"Salvestatud: {failinimi.name}")


def main() -> None:
    """Loeb argumendid, kogub inventuuri ja väljastab tulemuse."""
    parser = argparse.ArgumentParser(description="Süsteemi inventuur")
    parser.add_argument("--väljund", dest="valjund", help="JSON-fail (vaikimisi automaatselt)")
    parser.add_argument("--stdout", action="store_true", help="Prindi JSON konsooli, ära salvesta faili")
    args = parser.parse_args()

    inventuur = kogu_inventuur()

    if args.stdout:
        print(json.dumps(inventuur, indent=2, ensure_ascii=False))
        return

    if args.valjund:
        fail = Path(args.valjund)
    else:
        kp = datetime.now().strftime("%Y-%m-%d")
        fail = Path(f"inventuur_{inventuur['host']}_{kp}.json")

    fail.write_text(
        json.dumps(inventuur, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    prindi_kokkuvote(inventuur, fail)


if __name__ == "__main__":
    main()