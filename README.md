# VÁGÁNYMESTER — WPF forgalmi szolgálattevő szimulátor

Saját, tanulásra és játékra készült, egyállomásos **C# / WPF** szimulátor.

## Megnyitás Windows alatt

**Előfeltétel:** Windows 10/11, Visual Studio 2022 **17.13 vagy újabb** (WPF/.NET Desktop development komponenssel), vagy Visual Studio 2026, illetve .NET 8 SDK. A `.slnx` megoldásformátumhoz Visual Studio 2022 17.13+ vagy a .NET 9+ CLI ajánlott.

1. Csomagold ki a ZIP-et.
2. Dupla kattintással nyisd meg a `Vaganymester.slnx` fájlt Visual Studióban.
3. Válaszd a **Vaganymester** projektet indítási projektként.
   Alternatívaként dupla kattintással indíthatod az `INDITAS_WINDOWS.bat` fájlt (telepített .NET 8 SDK esetén).
4. Nyomd meg az **F5**-öt vagy az **Indítás** gombot.

Ha Visual Studio helyett parancssorból akarod futtatni, Windows alatt, megfelelő .NET SDK-val:

A kicsomagolt mappából futtasd:

```powershell
dotnet run --project .\Vaganymester\Vaganymester.csproj
```

**Fontos:** a WPF Windows-specifikus, Linuxon és macOS-en nem fut.

## Játékmenet

- A menetrendben szereplő vonatok maguktól érkeznek **nyugatról és keletről**.
- A bejárati és kijárati jelzők alaphelyzetben vörösek. A **Jelző / váltó** fülön kiválasztva nyithatók vagy zárhatók.
- Két váltó határozza meg, hogy a vonat az **1. vagy 2. vágányra** kerüljön, és melyik ágon hagyhatja el az állomást.
- A biztonságos vágányút-ellenőrzés megakadályozza a foglalt pályára vezető vágányút beállítását, és lezárja az igénybe vett váltót.
- A jelzők a vonat elhaladásakor automatikusan vörösre állnak vissza.
- A **Vonatok** fülön a kiválasztott mozdonyvezetőnek indulási, megállási, vészfékezési vagy veszélyes jelzőmeghaladási utasítást adhatsz.
- A **Személyzet** fülön külön mozdonyvezetők és rádióállapotuk látszik. Különböző fékezési reakciójuk van.
- A menetrend és az időbélyeges eseménynapló valós időben frissül.
- Új, rendkívüli személy-, IC- vagy tehervonatot is indíthatsz.
- A szimuláció sebessége **1–5×** között állítható. Szüneteltetés, +1 mp léptetés és újraindítás elérhető.

## Első sikeres menet — nyugatról keletre

1. A `W1` (nyugati) váltót hagyd az **1. vágányon**.
2. Állítsd az **N-BE** jelzőt **SZABAD** állásba, még mielőtt az első személyvonat odaérne.
3. A vonat belép az 1. vágányra, és a kijárati jelző előtt várakozik.
4. A `W2` (keleti) váltót is állítsd **1. vágány** állásba.
5. Ha a keleti vonalszakasz szabad, állítsd a **V1-K** kijárati jelzőt **SZABAD** állásba.
6. A vonat elhagyja az állomást; a teljesítés megjelenik a menetrendben.

Ugyanez keletről nyugatra: `W2` + `K-BE` bejárat, `W1` + `V1-N`/`V2-N` kijárat.

## Ütközéses próba

Az ütközések **szándékosan előidézhetők** az oktatási modellben. Például az 1. vágányra engedett egyik vonattal szemben a másik vonatot is ugyanoda engedheted, ha kikapcsolod a biztonságos vágányút-ellenőrzést, vagy a **Vörös meghaladása** utasítást adod ki. A vonatok fizikai helyzetét ellenőrzi a program, és átfedésnél balesetet naplóz, vörösre állít minden jelzőt, megállítja a forgalmat. Újraindítással kezdhető új szolgálat.

## Vezérlés

| Billentyű | Funkció |
|---|---|
| Space | Indítás / szünet |
| F2 | Rendkívüli személyvonat nyugatról |
| F3 | Rendkívüli személyvonat keletről |
| F5 | +1 mp léptetés |
| F9 | Újraindítás |

## Forráskód felépítése

- `Vaganymester.slnx` — Visual Studio megoldásfájl
- `Vaganymester/Vaganymester.csproj` — .NET 8 / WPF projekt
- `MainWindow.xaml` — kezelőpult és vágányrajz
- `MainWindow.xaml.cs` — gombok, billentyűk, WPF-időzítő
- `Models/` — vonat, mozdonyvezető, jelző, váltó, menetrend, események
- `Simulation/DispatchEngine.cs` — vágányút-ellenőrzés, vonatmozgás, fékezés, ütközések, menetrend

**Korlátok:** fiktív kétvágányos állomás, egyszerűsített kitérőgeometria és fékmodell, egyetlen vonalirány állomásonként; nincs teljes vasúti blokkbiztosítás, vágányútoldás, fékgörbe vagy szabályzati megfelelőség. A program kizárólag játék és oktatási célra készült, valódi vasúti forgalom irányítására nem használható.

### Új funkció: vonat belső nézete

- A pályarajzon egy vonatra kattintva külön WPF-ablak nyílik. A VONATOK fülön az **Utastér / ülésrajz** gombbal vagy a listán dupla kattintással is megnyitható.
- Személyvonaton 3, InterCityn 4 személykocsi látszik. Kocsinként A–D ülések, kétoldali üléspárok és középső folyosó található.
- A foglalt helyek mellett szimulált magyar utasnevek, jegytípusok, valamint a foglalt/szabad helyek száma és az összesített kihasználtság látszik.
- Egy ülésre kattintva szerkeszthető a rajta lévő utas vagy felszabadítható a hely. Az adatok a vonat objektumában maradnak, az ablak bezárása nem törli őket.
- A tehervonatnak nincs utastér; ezt a külön ablak jelzi.
- Az utasnevek automatikusan generált tesztadatok, nem valós utasok.
