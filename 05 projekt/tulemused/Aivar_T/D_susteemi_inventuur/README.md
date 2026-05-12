\# Süsteemi inventuur



See Pythoni skript kogub arvuti põhilised süsteemiandmed ja salvestab need JSON-faili. Lisaks kuvab skript konsoolis lühikese kokkuvõtte süsteemi kohta.



\## Projekti failid



\- `inventuur.py` – põhiskript

\- `inventuur\_demo-host\_2026-04-21.json` – näidisväljund

\- `requirements.txt` – vajalikud sõltuvused

\- `README.md` – kasutusjuhend ja disainiotsuste kirjeldus



\## Eeldused



Enne skripti käivitamist peab olema paigaldatud vajalik teek:



```powershell

pip install -r requirements.txt

```



\## Käivitamine



Ava PowerShell ja liigu projekti kausta:



```powershell

cd "C:\\Users\\tahka\\skriptimisvahendid\\05 projekt\\tulemused\\Aivar\_T\\D\_susteemi\_inventuur"

```



Käivita skript tavarežiimis:



```powershell

python .\\inventuur.py

```



See salvestab inventuuri JSON-faili automaatselt nimega kujul:



```text

inventuur\_<hostname>\_<kuupäev>.json

```



Käivita skript ja määra väljundfail ise:



```powershell

python .\\inventuur.py --väljund .\\minu\_inventuur.json

```



Käivita skript nii, et JSON prinditakse konsooli:



```powershell

python .\\inventuur.py --stdout

```



\## Mida skript teeb



Skript:



\- kogub hosti nime, kasutaja ja Pythoni versiooni

\- kogub operatsioonisüsteemi andmed

\- kogub CPU andmed

\- kogub mälu andmed

\- kogub ketaste info

\- kogub võrguliideste info

\- salvestab tulemuse JSON-faili

\- kuvab konsoolis lühikese kokkuvõtte



\## Disainiotsused



\### `argparse`



Kasutasin `argparse` moodulit, et väljundfaili saaks käsurealt muuta ja vajadusel JSON-i otse konsooli printida.



\### `psutil`



Kasutasin `psutil` teeki, sest see võimaldab mugavalt lugeda süsteemi infot, näiteks mälu, kettakasutust ja võrguliideseid.



\### Funktsioonideks jagamine



Jagasin programmi väiksemateks funktsioonideks:



\- `kogu\_host()` – hosti, kasutaja ja Pythoni info

\- `kogu\_os()` – operatsioonisüsteemi info

\- `kogu\_cpu()` – protsessori info

\- `kogu\_malu()` – mälu info

\- `kogu\_kettad()` – ketaste info

\- `kogu\_vork()` – võrguliideste info

\- `kogu\_inventuur()` – lõpliku andmestruktuuri koostamine

\- `prindi\_kokkuvote()` – loetav väljund konsooli



\### JSON-väljund



Valisin väljundvorminduseks JSON-i, sest see on hästi loetav ja sobib edasi töötlemiseks teistes skriptides või tööriistades.



\### Võrguliideste käsitlemine



Võrguliidesed jätsin alles ka siis, kui need ei ole aktiivsed. Nii annab inventuur parema ülevaate arvutis olemasolevatest adapteritest.



\### Inimloetav kokkuvõte



Lisaks JSON-failile kuvatakse tavarežiimis lühikokkuvõte konsooli, et kasutaja näeks kohe olulisemaid süsteemiandmeid ilma faili avamata.



\## Autor



Aivar T


