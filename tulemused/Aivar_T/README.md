\# Saada-Teavitus



See lahendus saadab PowerShelli kaudu teavitusi Discordi kanalisse, kasutades webhooki ja REST API päringut.



\## Failid



\- `Saada-Teavitus.psm1` – PowerShelli moodul funktsiooniga `Send-AlertMessage`

\- `config.example.psd1` – näidiskonfiguratsioon

\- `.gitignore` – jätab `config.psd1` Gitist välja



\## Funktsionaalsus



Moodul võimaldab saata teavitusi järgmiste parameetritega:



\- `-Message` – kohustuslik teate tekst

\- `-Severity` – `Info`, `Warning` või `Critical`

\- `-Source` – teate allikas, vaikimisi arvuti nimi



Teavitus saadetakse Discordi webhooki kaudu ning igast saatmisest kirjutatakse logi faili:



\- `%TEMP%\\ps-alerts.log`



\## Näited



```powershell

Import-Module .\\Saada-Teavitus.psm1 -Force

Send-AlertMessage -Message "Serveriketas 90% täis" -Severity Warning

Send-AlertMessage -Message "Kriitiline fail kustutatud" -Severity Critical -Source "DC01"

