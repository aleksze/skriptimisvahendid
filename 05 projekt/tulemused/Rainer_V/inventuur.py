import argparse
import json
import platform
import socket
import getpass
from datetime import datetime, timezone
from pathlib import Path

import psutil


def kogu_os() -> dict:
    """Tagastab OS info."""
    return {
        "süsteem": platform.system(),
        "versioon": platform.version(),
        "release": platform.release(),
        "arhitektuur": platform.architecture()[0],
    }


def kogu_host() -> dict:
    """Tagastab hosti ja kasutaja info."""
    return {
        "host": socket.gethostname(),
        "kasutaja": getpass.getuser(),
        "python": platform.python_version(),
    }


def kogu_cpu() -> dict:
    """Tagastab CPU info."""
    mudel = platform.processor()

    if platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo") as f:
                for rida in f:
                    if rida.startswith("model name"):
                        mudel = rida.split(":", 1)[1].strip()
                        break
        except Exception:
            pass

    if not mudel:
        mudel = "Teadmata"

    return {
        "mudel": mudel or "Teadmata",
        "südamikud_füüsilised": psutil.cpu_count(logical=False),
        "südamikud_loogilised": psutil.cpu_count(logical=True),
        "kasutus_protsent": psutil.cpu_percent(interval=1),
    }


def kogu_mälu() -> dict:
    """Tagastab mälu info."""
    m = psutil.virtual_memory()
    return {
        "kokku_gb": round(m.total / (1024**3), 2),
        "kasutuses_gb": round(m.used / (1024**3), 2),
        "vaba_gb": round(m.available / (1024**3), 2),
        "kasutus_protsent": m.percent,
    }


def kogu_kettad() -> list[dict]:
    """Tagastab kettaste info."""
    kettad = []
    for osa in psutil.disk_partitions(all=False):
        try:
            kasutus = psutil.disk_usage(osa.mountpoint)
        except (PermissionError, OSError):
            continue

        kettad.append({
            "haakepunkt": osa.mountpoint,
            "seade": osa.device,
            "failisüsteem": osa.fstype,
            "kokku_gb": round(kasutus.total / (1024**3), 2),
            "vaba_gb": round(kasutus.free / (1024**3), 2),
            "kasutus_protsent": kasutus.percent,
        })
    return kettad


def kogu_võrk() -> list[dict]:
    """Tagastab võrgukaartide info."""
    kaardid = []
    aadressid = psutil.net_if_addrs()
    olek = psutil.net_if_stats()

    for nimi, adrlist in aadressid.items():
        ipv4 = next(
            (a.address for a in adrlist if a.family == socket.AF_INET and not a.address.startswith("127.")),
            None
        )
        on_üleval = olek[nimi].isup if nimi in olek else False

        kaardid.append({
            "nimi": nimi,
            "ipv4": ipv4,
            "ühendatud": on_üleval,
        })
    return kaardid


def prindi_kokkuvote(inv: dict) -> None:
    """Prindib konsooli loetava kokkuvõtte."""
    print("=== Süsteemi inventuur ===")
    print(f"Host:        {inv['host']}")
    print(f"Kasutaja:    {inv['kasutaja']}")
    print(f"OS:          {inv['os']['süsteem']} {inv['os']['release']} ({inv['os']['versioon']})")
    print(f"Python:      {inv['python']}")
    print()

    cpu = inv["cpu"]
    print(f"CPU:         {cpu['mudel']}")
    print(f"Südamikke:   {cpu['südamikud_füüsilised']} ({cpu['südamikud_loogilised']} loogilist)")

    m = inv["mälu"]
    print(f"RAM:         {m['kokku_gb']} GB (kasutuses {m['kasutus_protsent']}%)")
    print()

    print("Kettad:")
    for k in inv["kettad"]:
        print(f"  {k['haakepunkt']:5} Kokku: {k['kokku_gb']} GB  Vaba: {k['vaba_gb']} GB  ({100 - k['kasutus_protsent']:.0f}% vaba)")
    print()

    print("Võrgukaardid:")
    for v in inv["võrk"]:
        ip = v["ipv4"] if v["ipv4"] else "(ühendamata)"
        print(f"  {v['nimi']:20} {ip}")


def main():
    parser = argparse.ArgumentParser(description="Süsteemi inventuur")
    parser.add_argument("--väljund", help="JSON-fail (vaikimisi automaatne nimi)")
    parser.add_argument("--stdout", action="store_true", help="Prindi JSON konsooli")
    args = parser.parse_args()

    inventuur = {
        "ajamäär": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        **kogu_host(),
        "os": kogu_os(),
        "cpu": kogu_cpu(),
        "mälu": kogu_mälu(),
        "kettad": kogu_kettad(),
        "võrk": kogu_võrk(),
    }

    if args.stdout:
        print(json.dumps(inventuur, indent=2, ensure_ascii=False))
        return

    prindi_kokkuvote(inventuur)

    if args.väljund:
        fail = Path(args.väljund)
    else:
        kp = datetime.now().strftime("%Y-%m-%d")
        fail = Path(f"inventuur_{inventuur['host']}_{kp}.json")

    fail.write_text(json.dumps(inventuur, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSalvestatud: {fail}")


if __name__ == "__main__":
    main()
