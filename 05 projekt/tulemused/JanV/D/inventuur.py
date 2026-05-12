"""
inventuur.py — KIT-24 Iseseisev töö, ülesanne D
=================================================
Kogub süsteemiinfo (OS, CPU, RAM, kettad, võrk) ja salvestab JSON-faili.
Ristplatformne: Windows, macOS, Linux.

Kasutus:
  python inventuur.py                        # vaikimisi — salvestab JSON-faili
  python inventuur.py --väljund minu.json    # kohandatud failinimi
  python inventuur.py --stdout               # prindib JSON konsooli
  python inventuur.py --stdout | jq .cpu     # torustikus kasutamine
"""

import argparse
import getpass
import json
import platform
import socket
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import psutil
    PSUTIL_OLEMAS = True
except ImportError:
    PSUTIL_OLEMAS = False
    print("Hoiatus: psutil pole paigaldatud — mõned väljad puuduvad. "
          "Paigalda: pip install psutil", file=sys.stderr)


# ---------------------------------------------------------------------------
# 1. OS ja hosti info
# ---------------------------------------------------------------------------

def kogu_os() -> dict:
    """Tagastab operatsioonisüsteemi ja platvormi info."""
    süsteem = platform.system()
    # platform.system() tagastab 'Darwin' macOS-i puhul — teisendame loetavaks
    os_nimed = {"Darwin": "macOS", "Linux": "Linux", "Windows": "Windows"}

    return {
        "süsteem":     os_nimed.get(süsteem, süsteem),
        "versioon":    platform.version(),
        "release":     platform.release(),
        "arhitektuur": platform.architecture()[0],  # '64bit' / '32bit'
        "masina_tüüp": platform.machine(),           # 'AMD64', 'x86_64', 'arm64'
    }


def kogu_host() -> dict:
    """Tagastab hosti nime, kasutajanime ja Pythoni versiooni."""
    return {
        "host":     socket.gethostname(),
        "kasutaja": getpass.getuser(),
        "python":   platform.python_version(),
    }


# ---------------------------------------------------------------------------
# 2. CPU info
# ---------------------------------------------------------------------------

def kogu_cpu() -> dict:
    """Tagastab protsessori mudeli, südamike arvu ja hetkekasutuse."""
    mudel = platform.processor()

    # Linuxis on platform.processor() sageli tühi — loe /proc/cpuinfo
    if not mudel and platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo", encoding="utf-8") as f:
                for rida in f:
                    if rida.startswith("model name"):
                        mudel = rida.split(":", 1)[1].strip()
                        break
        except Exception:
            mudel = "Teadmata"

    if not PSUTIL_OLEMAS:
        return {
            "mudel":                mudel or "Teadmata",
            "südamikud_füüsilised": "teadmata",
            "südamikud_loogilised": "teadmata",
            "kasutus_protsent":     "teadmata",
        }

    return {
        "mudel":                mudel or "Teadmata",
        "südamikud_füüsilised": psutil.cpu_count(logical=False),
        "südamikud_loogilised": psutil.cpu_count(logical=True),
        # interval=1 blokeerib 1 sek — ilma selleta tagastab 0.0 esimesel kutsel
        "kasutus_protsent":     psutil.cpu_percent(interval=1),
    }


# ---------------------------------------------------------------------------
# 3. Mälu info
# ---------------------------------------------------------------------------

def kogu_mälu() -> dict:
    """Tagastab RAM-i mahu ja kasutuse.

    Kasutab m.available (mitte m.free), kuna available arvestab
    ka cache'i mida saaks vabastada — see on tegelik vaba mälu.
    """
    if not PSUTIL_OLEMAS:
        return {"kokku_gb": "teadmata", "kasutuses_gb": "teadmata",
                "vaba_gb": "teadmata", "kasutus_protsent": "teadmata"}

    try:
        m = psutil.virtual_memory()
        return {
            "kokku_gb":         round(m.total    / (1024**3), 2),
            "kasutuses_gb":     round(m.used     / (1024**3), 2),
            "vaba_gb":          round(m.available / (1024**3), 2),
            "kasutus_protsent": m.percent,
        }
    except Exception:
        return {"kokku_gb": "teadmata", "kasutuses_gb": "teadmata",
                "vaba_gb": "teadmata", "kasutus_protsent": "teadmata"}


# ---------------------------------------------------------------------------
# 4. Kettad
# ---------------------------------------------------------------------------

def kogu_kettad() -> list[dict]:
    """Tagastab loendi ketaste kohta (haakepunkt, suurus, vaba ruum).

    all=False jätab välja virtuaalsed failisüsteemid
    (Linuxis /proc, /sys jne) — muidu tuleb liiga palju müra.
    """
    if not PSUTIL_OLEMAS:
        return []

    kettad = []
    for osa in psutil.disk_partitions(all=False):
        try:
            kasutus = psutil.disk_usage(osa.mountpoint)
        except (PermissionError, OSError):
            continue  # mõnda ketast ei pruugi saada lugeda

        kettad.append({
            "haakepunkt":       osa.mountpoint,
            "seade":            osa.device,
            "failisüsteem":     osa.fstype,
            "kokku_gb":         round(kasutus.total / (1024**3), 2),
            "kasutatud_gb":     round(kasutus.used  / (1024**3), 2),
            "vaba_gb":          round(kasutus.free  / (1024**3), 2),
            "kasutus_protsent": kasutus.percent,
        })
    return kettad


# ---------------------------------------------------------------------------
# 5. Võrgukaardid
# ---------------------------------------------------------------------------

def kogu_võrk() -> list[dict]:
    """Tagastab loendi võrgukaartidest koos IPv4 aadressi ja olekuga.

    Loopback (127.x) filtreeritakse välja — ei ole infomatsiooni.
    Ühendamata kaardid jäetakse sisse (ipv4=null, ühendatud=false).
    """
    if not PSUTIL_OLEMAS:
        return []

    try:
        aadressid = psutil.net_if_addrs()
        olek      = psutil.net_if_stats()
    except Exception:
        return []

    kaardid = []
    for nimi, adrlist in aadressid.items():
        # next(..., None) — leia esimene IPv4 mis pole loopback, või None
        ipv4 = next(
            (a.address for a in adrlist
             if a.family == socket.AF_INET and not a.address.startswith("127.")),
            None
        )
        on_üleval = olek[nimi].isup if nimi in olek else False

        kaardid.append({
            "nimi":      nimi,
            "ipv4":      ipv4,
            "ühendatud": on_üleval,
        })
    return kaardid


# ---------------------------------------------------------------------------
# 6. Konsooli kokkuvõte
# ---------------------------------------------------------------------------

def prindi_kokkuvote(inv: dict) -> None:
    """Prindib inimloetava kokkuvõtte konsooli."""
    os_info = inv["os"]
    cpu     = inv["cpu"]
    mälu    = inv["mälu"]

    print("\n=== Süsteemi inventuur ===")
    print(f"Host:        {inv['host']}")
    print(f"Kasutaja:    {inv['kasutaja']}")
    print(f"OS:          {os_info['süsteem']} {os_info['release']} ({os_info['versioon'][:20]})")
    print(f"Python:      {inv['python']}")

    print(f"\nCPU:         {cpu['mudel']}")
    print(f"Südamikke:   {cpu['südamikud_füüsilised']} ({cpu['südamikud_loogilised']} loogilist)")
    print(f"Kasutus:     {cpu['kasutus_protsent']}%")

    print(f"\nRAM:         {mälu['kokku_gb']} GB (kasutuses {mälu['kasutus_protsent']}%)")

    print("\nKettad:")
    for k in inv["kettad"]:
        vaba_prot = round(100 - k["kasutus_protsent"])
        print(f"  {k['haakepunkt']:<6} Total: {k['kokku_gb']} GB  "
              f"Free: {k['vaba_gb']} GB  ({vaba_prot}% vaba)")

    print("\nVõrgukaardid:")
    for v in inv["võrk"]:
        ip_tekst = v["ipv4"] if v["ipv4"] else "(ühendamata)"
        print(f"  {v['nimi']:<20} {ip_tekst}")


# ---------------------------------------------------------------------------
# 7. Peaprogramm
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Süsteemi inventuur — KIT-24 ülesanne D")
    parser.add_argument(
        "--väljund",
        help="JSON-faili tee (vaikimisi: inventuur_<host>_<kuupäev>.json)",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Prindi JSON konsooli, ära salvesta faili (kasulik: python inventuur.py --stdout | jq .)",
    )
    args = parser.parse_args()

    # Kogu kõik info kokku
    # **kogu_host() pakib host/kasutaja/python samale tasemele ülejäänuga
    inventuur = {
        "ajamäär": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        **kogu_host(),
        "os":      kogu_os(),
        "cpu":     kogu_cpu(),
        "mälu":    kogu_mälu(),
        "kettad":  kogu_kettad(),
        "võrk":    kogu_võrk(),
    }

    # --stdout režiim: prindi JSON, ära salvesta
    if args.stdout:
        try:
            print(json.dumps(inventuur, indent=2, ensure_ascii=False))
        except BrokenPipeError:
            pass  # normaalne kui torustik (| head jne) lõpetab varem
        return

    # Tavaline režiim: kokkuvõte + JSON-fail
    prindi_kokkuvote(inventuur)

    fail = Path(args.väljund) if args.väljund else \
           Path(f"inventuur_{inventuur['host']}_{datetime.now().strftime('%Y-%m-%d')}.json")

    fail.write_text(
        json.dumps(inventuur, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"\nSalvestatud: {fail}")


if __name__ == "__main__":
    main()
