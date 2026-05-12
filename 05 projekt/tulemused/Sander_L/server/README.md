# Serverite saadavuse monitor

## Käivitamine

Vaikimisi loeb `hostid.csv`, salvestab `saadavus_<kuupäev>.csv`


TCP kontroll (`Test-NetConnection`) kui port on määratud, ICMP ping
CSV failinimi sisaldab kuupäeva, et mitu jooksu säiliks
Konsooliväljund värvikoodiga — roheline OK, punane FAIL

## Teavitus

Kui üks või mitu hosti on maas, saadetakse automaatselt Discord teavitus.
Nõuab keskkonnamuutujat `ALERT_WEBHOOK` (Discord webhook URL).