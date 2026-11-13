# VÁGÁNYMESTER Mobile

A WPF-játék mellett fejlődő, fekvő tájolású Flutter + Flame vasúti
forgalomirányító játék. A WPF-kód változatlanul elérhető a gyökérben.

## 0.2.0 – irányítás és játékélmény

- Belépőképernyő **vendégjátékosnévvel**, valódi azonosítás nélkül
- Főmenü, beállítások, 20 rekordot őrző **offline helyi ranglista**
- Fekvő Android-mód natív beállítással, kétujjas **pinch-to-zoom**
  és térképmozgatás; + / − / középre gombok
- Fenyvesliget és Tiszaváros 3-3, Kőröspatak **4 állomási vágánnyal**
- Külön nyugati és keleti váltóválasztás, bejárati és kijárati jelzők
- Vágányonkénti lezárás, vonali vágányzár és peronfoglaltság-ellenőrzés
- Kézi vagy automatikus biztosítóberendezési játékmód
- +100 pont megérkezésenként, sorozatbónusz és IC-bónusz
- 3 élet, választható veszélyes játékmód, ütközéskor -1 élet/-250 pont;
  0 életnél játék vége és rekord mentése
- Szünet, 1×/10×/30×/60× gyorsítás, vészstop
- Eredmények és beállítások helyi tárolása SharedPreferences-szel
- 10 szimulációs egységteszt és automatikus GitHub APK-build

**Fontos:** a szimuláció oktatási játék, nem valós vasúti biztosítóberendezés.
A grafikus pályarajz immár több állomási vágányt ábrázol, de a WPF összes
ablaka és az összes részletes biztosítóberendezési szabály még nincs
teljesen átültetve. Nincs még teljes menetrendszerkesztő, utastér, fizikai
baleseti animáció, karriermód, felhőalapú autentikáció, online ranglista
vagy tartós szimulációs állásmentés.

## Első indítás és kezelés

1. A kezdőképernyőn adj meg egy tetszőleges nevet.
2. Az **ÚJ SZOLGÁLAT** gombbal indul a játék.
3. Érintsd meg az állomást vagy a vonatot az irányítópulthoz.
4. A **Beállítások** menüben válthatsz kézi/automata mód és
   kockázatos/normál mód között.
5. Kézi módban állítsd a kiinduló állomás megfelelő kijárati váltóját
   a vonat vágányára, a fogadó állomás bejárati váltóját egy szabad
   peronra, majd mindkét jelzőt **SZABAD** állásra.
   Végül a vonat adatlapján nyomd meg az **Indulás engedélyezése** gombot.
6. A játék elején például az S 2412 indul Fenyvesligetről Kőröspatakra:
   Fenyvesliget keleti kijárati jelzője, Kőröspatak nyugati bejárati
   jelzője és nyugati váltója szükséges.
7. A **Főmenü** gombbal a szolgálat lezárul, és a pozitív pontszám
   elmenthető az eszköz helyi ranglistájába. Játék végén automatikus.

A **veszélyes indítás** külön jóváhagyást kér, és csak akkor okoz
játékon belüli ütközést, ha ugyanarra a szakaszra már közlekedik vonat.
Biztonságos üzemben ezt a motor tiltja.

## Indítás fejlesztői gépen

Flutter 3.47.9:

\`\`\`sh
cd mobile
flutter create --platforms=android,ios --org hu.merenyimiklos --project-name vaganymester .
flutter pub get
flutter analyze
flutter test
flutter run
\`\`\`

Az Android és iOS natív könyvtárak egyelőre Flutter-rel újragenerálódnak,
a GitHub Actions az Android manifesthez rögzíti a landscape tájolást.

## APK GitHub Action

GitHub → **Actions** → **VAGANYMESTER Android APK** → legutóbbi zöld futás
→ **Artifacts** → \`Vaganymester-Android-APK-...\` → ZIP kibontása
→ \`app-release.apk\` telepítése.

Automatikus futás: \`master\` branch, \`mobile/**\` módosítások.
Kézi indítás: **Run workflow**.

A tesztelési APK nem áruházi kiadáshoz aláírt végleges build.

## Architektúra

- \`lib/data/session_store.dart\`: vendégnév, beállítások, helyi ranglista
- \`lib/game/simulation.dart\`: vonatok, állomások, peronok, jelzők, váltók,
  szakaszfoglaltság, pontok, életek és veszélyes ütközési játékállapot
- \`lib/game/railway_game.dart\`: Flame hálózat, járművek, kameramozgás, pinch
- \`lib/ui/main_menu.dart\`: kezdőképernyő, belépés, beállítások, ranglista
- \`lib/ui/station_controls_panel.dart\`: WPF-stílusú állomási irányítópult
- \`lib/ui/dispatch_screen.dart\`: játéknézet, HUD, adatlap, játék vége

Következő fejlesztési lépések: még részletesebb WPF-vágányrajz és
vágányútfoglalási szabályok, menetrend, utastér, küldetések, mentés.
