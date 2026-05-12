import platform
import socket
import getpass
import json
import argparse
import psutil
import requests # type: ignore
from datetime import datetime, timezone
from pathlib import Path


# ---------------- OS  ----------------

def kogu_os() -> dict:
    return {
        "süsteem": platform.system(),
        "versioon": platform.version(),
        "release": platform.release(),
        "arhitektuur": platform.architecture()[0],
        "masina_tüüp": platform.machine(),
    }


def kogu_host() -> dict:
    return {
        "host": socket.gethostname(),
        "kasutaja": getpass.getuser(),
        "python": platform.python_version(),
    }


# ---------------- CPU ----------------

def kogu_cpu() -> dict:
    mudel = platform.processor()

    if not mudel and platform.system() == "Linux":
        try:
            with open("/proc/cpuinfo") as f:
                for rida in f:
                    if "model name" in rida:
                        mudel = rida.split(":", 1)[1].strip()
                        break
        except Exception:
            mudel = "Teadmata"

    return {
        "mudel": mudel or "Teadmata",
        "südamikud_füüsilised": psutil.cpu_count(logical=False),
        "südamikud_loogilised": psutil.cpu_count(logical=True),
        "kasutus_protsent": psutil.cpu_percent(interval=1),
    }


# ---------------- MEMORY ----------------

def kogu_mälu() -> dict:
    m = psutil.virtual_memory()

    return {
        "kokku_gb": round(m.total / (1024 ** 3), 2),
        "kasutuses_gb": round(m.used / (1024 ** 3), 2),
        "vaba_gb": round(m.available / (1024 ** 3), 2),
        "kasutus_protsent": m.percent,
    }


# ---------------- DISK ----------------

def kogu_kettad() -> list[dict]:
    kettad = []

    for osa in psutil.disk_partitions(all=False):
        try:
            kasutus = psutil.disk_usage(osa.mountpoint)
        except Exception:
            continue

        kettad.append({
            "haakepunkt": osa.mountpoint,
            "seade": osa.device,
            "failisüsteem": osa.fstype,
            "kokku_gb": round(kasutus.total / (1024 ** 3), 2),
            "vaba_gb": round(kasutus.free / (1024 ** 3), 2),
            "kasutatud_gb": round(kasutus.used / (1024 ** 3), 2),
            "kasutus_protsent": kasutus.percent,
        })

    return kettad


# ---------------- NETWORK ----------------

def kogu_võrk() -> list[dict]:
    tulemused = []

    aadressid = psutil.net_if_addrs()
    stats = psutil.net_if_stats()

    for nimi, addrs in aadressid.items():

        ipv4 = next(
            (a.address for a in addrs
             if a.family == socket.AF_INET and not a.address.startswith("127.")),
            None
        )

        tulemused.append({
            "nimi": nimi,
            "ipv4": ipv4,
            "ühendatud": stats[nimi].isup if nimi in stats else False
        })

    return tulemused


# ---------------- DISCORD ----------------

def saada_discord_webhook(inv: dict, webhook_url: str) -> None:
    """Saadab inventuuri Discordi webhookile (turvaline versioon)."""

    try:
        content = (
            f"🖥 **Süsteemi inventuur**\n"
            f"Host: {inv['host']}\n"
            f"Kasutaja: {inv['kasutaja']}\n"
            f"OS: {inv['os']['süsteem']} {inv['os']['release']}\n"
            f"CPU: {inv['cpu']['mudel']}\n"
            f"RAM: {inv['mälu']['kokku_gb']} GB ({inv['mälu']['kasutus_protsent']}%)\n"
        )

        payload = {
            "content": content
        }

        response = requests.post(webhook_url, json=payload)

        if response.status_code == 204:
            print("Discord: OK")
        else:
            print(f"Discord error: {response.status_code} {response.text}")

    except Exception as e:
        print(f"Discord exception: {e}")


# ---------------- CONSOLE ----------------

def prindi_kokkuvote(inv: dict) -> None:
    print("=== Süsteemi inventuur ===")
    print(f"Host:        {inv['host']}")
    print(f"Kasutaja:    {inv['kasutaja']}")
    print(f"OS:          {inv['os']['süsteem']} {inv['os']['release']}")
    print(f"Python:      {inv['python']}\n")

    print(f"CPU:         {inv['cpu']['mudel']}")
    print(f"Südamikke:   {inv['cpu']['südamikud_füüsilised']} "
          f"({inv['cpu']['südamikud_loogilised']} loogilist)")
    print(f"CPU kasutus: {inv['cpu']['kasutus_protsent']}%\n")

    print(f"RAM:         {inv['mälu']['kokku_gb']} GB "
          f"({inv['mälu']['kasutus_protsent']}%)\n")

    print("Kettad:")
    for d in inv["kettad"]:
        print(f"  {d['haakepunkt']}  Total: {d['kokku_gb']} GB  "
              f"Free: {d['vaba_gb']} GB")

    print("\nVõrk:")
    for n in inv["võrk"]:
        ip = n["ipv4"] if n["ipv4"] else "(ühendamata)"
        print(f"  {n['nimi']:<15} {ip}")


# ---------------- MAIN ----------------

def main():
    parser = argparse.ArgumentParser(description="Süsteemi inventuur")
    parser.add_argument("--väljund", help="JSON failinimi")
    parser.add_argument("--stdout", action="store_true")
    parser.add_argument("--webhook", help="Discord webhook URL")
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

    # stdout mode
    if args.stdout:
        print(json.dumps(inventuur, indent=2, ensure_ascii=False))
        return

    # console output
    prindi_kokkuvote(inventuur)

    # filename
    kuup = datetime.now().strftime("%Y-%m-%d")
    failinimi = args.väljund or f"inventuur_{inventuur['host']}_{kuup}.json"

    Path(failinimi).write_text(
        json.dumps(inventuur, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )

    print(f"\nSalvestatud: {failinimi}")

    # discord parse
    if args.webhook:
        saada_discord_webhook(inventuur, args.webhook)


if __name__ == "__main__":
    main()