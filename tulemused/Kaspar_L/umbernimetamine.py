import os
from datetime import datetime

kaust = "."

# tänane kuupäev formaadis 2026-03-24
tana = datetime.now().strftime("%Y-%m-%d")

print("Failid enne ümbernimetamist:")
print("-" * 35)

failid = os.listdir(kaust)
for failinimi in failid:
    print(failinimi)

print("\nTöötlen failinimesid...")
print("-" * 35)

for failinimi in os.listdir(kaust):

    vana_tee = os.path.join(kaust, failinimi)

    # väldi kaustade muutmist
    if not os.path.isfile(vana_tee):
        continue

    uus_nimi = failinimi

    # 1. tee väiketähtedeks
    uus_nimi = uus_nimi.lower()

    # 2. asenda tühikud
    uus_nimi = uus_nimi.replace(" ", "_")

    # 3. lisa failitüübi prefix
    if uus_nimi.endswith(".jpg") and not uus_nimi.startswith("pilt_"):
        uus_nimi = "pilt_" + uus_nimi

    elif uus_nimi.endswith(".txt") and not uus_nimi.startswith("tekst_"):
        uus_nimi = "tekst_" + uus_nimi

    # 4. lisa kuupäev ette (AGA ainult siis kui pole juba)
    if not uus_nimi.startswith(tana):
        uus_nimi = f"{tana}_{uus_nimi}"

    uus_tee = os.path.join(kaust, uus_nimi)

    # väldi sama nime uuesti rename’imist
    if vana_tee != uus_tee:
        os.rename(vana_tee, uus_tee)
        print(f"{failinimi} → {uus_nimi}")

print("\nFailid pärast ümbernimetamist:")
print("-" * 35)
for failinimi in sorted(os.listdir(kaust)):
    print(failinimi)