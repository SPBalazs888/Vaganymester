# VÁGÁNYMESTER Mobile

Új Flutter + Flame mobiljáték a meglévő WPF-program mellett. Ez az első
**játszható prototípus**, nem a WPF-kód automatikus portolása.

## Első változat

- Fekvő tájolású, sötét témájú, interaktív hálózati térkép
- Három valódi állomás: Fenyvesliget, Kőröspatak, Tiszaváros
- Két valós modellezett, egyvágányú szakasz
- Három vonattípus, folyamatos állomásközi közlekedés, végállomási fordulás
- Egyszerre csak egy vonat tartózkodhat ugyanazon a szakaszon
- A fogadó állomáson előre ellenőrzött peronkapacitás
- Automatikus és kézi indítási engedély, IC-elsőbbség
- Kattintható vonatok és állomások, mozgatható/nagyítható térkép
- Vágányzár, vészleállítás, szimulációs óra és sebességállítás
- Automatikus tesztek a kritikus foglaltsági szabályokra

**Még nincs:** részletes állomási biztosítóberendezés, SQLite-mentés,
menetrend-szerkesztő, utastér, küldetések és karrier. Ezek a következő
különálló fejlesztési ütemek lesznek.

## Futtatás

Flutter 3.47.9 vagy kompatibilis verzió szükséges (Dart 3.13).

```bash
cd mobile
flutter create --platforms=android,ios --org hu.merenyimiklos --project-name vaganymester .
flutter pub get
flutter test
flutter run
```

A Flutter által generált android/ és ios/ platformkönyvtárak jelenleg
nincsenek verziókövetve. A GitHub Actions az Android shellt minden buildben
újragenerálja, ezért az APK-build reprodukálható a forrás alapján. iOS-es
teszteléshez macOS és Xcode szükséges.

## APK letöltése

1. GitHub repo → **Actions** → **VAGANYMESTER Android APK**.
2. A legutóbbi sikeres futásra kattintva az **Artifacts** résznél válaszd a
   `Vaganymester-Android-APK-...` állományt.
3. A GitHub artifact ZIP-ként csomagolja a kész `app-release.apk` fájlt.
   Csomagold ki, és telepítsd Androidra. Ez tesztelési build, nem Play
   Store kiadásra kész aláírt kiadvány.

A workflow automatikusan fut a `master` branch `mobile/**` változásain,
de az **Actions → Run workflow** gombbal kézzel is indítható.

## Architektúra

`lib/game/simulation.dart`: képkockáktól független állomás/szakasz/vonat
modell és biztonságos, léptetett szimulációs szabályok.

`lib/game/railway_game.dart`: Flame világ, mozgó vonatjelölők, térkép,
érintések, kamera.

`lib/ui/dispatch_screen.dart`: Flutter vezérlőpult, mobilos panelek,
vészstop, sebesség, kézi/automatikus vezérlés.

A jelenlegi modell **oktatási játék**, nem valódi vasúti
biztosítóberendezési rendszer.

## Következő ütemek

1. Több állomási vágány, jelző, váltó és vágányútbeállítás
2. Állomásonkénti menetrend, késések, valódi megállási idő
3. SQLite-alapú játékállás-mentés és visszatöltés
4. Modern kocsik, utasok, beszállás és leszállás
5. Karriermód, gazdaság, tutorial és publikálásra kész grafika
