import 'dart:math' as math;
import 'package:flutter/foundation.dart';

enum TrainKind { regional, intercity, freight }

class RailwayStation {
  const RailwayStation(this.id, this.name, this.mapX, {this.platforms = 2});

  final String id;
  final String name;
  final double mapX;
  final int platforms;
}

class TrackSection {
  TrackSection(this.id, this.from, this.to, this.lengthKm);

  final String id;
  final String from;
  final String to;
  final double lengthKm;
  bool closed = false;

  bool connects(String first, String second) =>
      (from == first && to == second) ||
      (from == second && to == first);
}

enum RailwaySide { west, east }
enum SignalKind { entry, exit }

class StationControls {
  StationControls(this.station);
  final RailwayStation station;
  int westTurnout = 0;
  int eastTurnout = 0;
  bool westEntry = false;
  bool eastEntry = false;
  bool westExit = false;
  bool eastExit = false;
  final Set<int> closedTracks = {};

  int turnout(RailwaySide side) =>
      side == RailwaySide.west ? westTurnout : eastTurnout;
  bool signal(RailwaySide side, SignalKind kind) {
    if (side == RailwaySide.west) {
      return kind == SignalKind.entry ? westEntry : westExit;
    }
    return kind == SignalKind.entry ? eastEntry : eastExit;
  }
  void selectTurnout(RailwaySide side, int index) {
    if (side == RailwaySide.west) {
      westTurnout = index;
    } else {
      eastTurnout = index;
    }
  }
  void setSignal(RailwaySide side, SignalKind kind, bool green) {
    if (side == RailwaySide.west) {
      if (kind == SignalKind.entry) {
        westEntry = green;
      } else {
        westExit = green;
      }
    } else {
      if (kind == SignalKind.entry) {
        eastEntry = green;
      } else {
        eastExit = green;
      }
    }
  }
  void allRed() {
    westEntry = false;
    eastEntry = false;
    westExit = false;
    eastExit = false;
  }
}

class SimTrain {
  SimTrain({
    required this.number,
    required this.kind,
    required this.driver,
    required List<String> route,
    required this.speedKmH,
    this.readyAt = 0,
  }) : route = List<String>.of(route);

  final String number;
  final TrainKind kind;
  final String driver;
  final double speedKmH;
  List<String> route;
  int leg = 0;
  double progress = 0;
  double readyAt;
  bool moving = false;
  bool authorized = false;
  int completedLegs = 0;
  int platformTrack = 0;
  int arrivalTrack = 0;

  String get currentStationId => route[leg];
  String get nextStationId => route[leg + 1];
  String get destinationId => route.last;
  bool get waiting => !moving;
  String get typeLabel => switch (kind) {
    TrainKind.regional => 'Személyvonat',
    TrainKind.intercity => 'InterCity',
    TrainKind.freight => 'Tehervonat',
  };
}

/// A megjelenítéstől független, determinisztikus oktatási játékmodell.
/// Egy szakaszon egyszerre csak egy vonat közlekedhet.
/// Az érkezési állomáson már induláskor lefoglalunk egy szabad peronhelyet.
class RailwaySimulation extends ChangeNotifier {
  final List<RailwayStation> stations = const [
    RailwayStation('fenyvesliget', 'Fenyvesliget', 170),
    RailwayStation('korospatak', 'Kőröspatak', 700, platforms: 4),
    RailwayStation('tiszavaros', 'Tiszaváros', 1230),
  ];

  final List<TrackSection> sections = [
    TrackSection('FV-KP', 'fenyvesliget', 'korospatak', 6),
    TrackSection('KP-TV', 'korospatak', 'tiszavaros', 6),
  ];

  late final Map<String, StationControls> stationControls = {
    for (final s in stations) s.id: StationControls(s),
  };

  final List<SimTrain> trains = [
    SimTrain(
      number: 'S 2412',
      kind: TrainKind.regional,
      driver: 'Kovács András',
      route: ['fenyvesliget', 'korospatak', 'tiszavaros'],
      speedKmH: 88,
      readyAt: 10,
    ),
    SimTrain(
      number: 'IC 502',
      kind: TrainKind.intercity,
      driver: 'Szabó Anna',
      route: ['tiszavaros', 'korospatak', 'fenyvesliget'],
      speedKmH: 120,
      readyAt: 30,
    ),
    SimTrain(
      number: 'G 921',
      kind: TrainKind.freight,
      driver: 'Nagy Péter',
      route: ['korospatak', 'tiszavaros'],
      speedKmH: 65,
      readyAt: 70,
    ),
  ];

  double elapsedSeconds = 0;
  int timeMultiplier = 30;
  bool running = true;
  bool emergency = false;
  bool automatic = true;
  int completedLegs = 0;
  int score = 0;
  int lives = 3;
  int combo = 0;
  int collisionCount = 0;
  bool gameOver = false;
  bool riskMode = false;
  String message = 'Állíts váltót és jelzőt, majd engedélyezd az indulást!';

  String get clock {
    final total = (8 * 3600 + elapsedSeconds.floor()) % (24 * 3600);
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total ~/ 60) % 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  int get movingCount => trains.where((t) => t.moving).length;
  int get waitingCount => trains.where((t) => !t.moving).length;

  RailwayStation station(String id) => stations.firstWhere((s) => s.id == id);
  SimTrain train(String id) => trains.firstWhere((t) => t.number == id);

  TrackSection sectionBetween(String from, String to) =>
      sections.firstWhere((s) => s.connects(from, to));

  SimTrain? occupying(TrackSection section) {
    for (final train in trains) {
      if (train.moving &&
          section.connects(train.currentStationId, train.nextStationId)) {
        return train;
      }
    }
    return null;
  }

  StationControls controls(String stationId) => stationControls[stationId]!;
  RailwaySide travelSide(SimTrain train) =>
      station(train.nextStationId).mapX > station(train.currentStationId).mapX
          ? RailwaySide.east : RailwaySide.west;
  RailwaySide opposite(RailwaySide side) =>
      side == RailwaySide.west ? RailwaySide.east : RailwaySide.west;

  bool trackReserved(String stationId, int track, {SimTrain? except}) =>
      trains.any((t) => !identical(t, except) &&
          (t.moving
              ? t.nextStationId == stationId && t.arrivalTrack == track
              : t.currentStationId == stationId && t.platformTrack == track));

  double mapHeight(SimTrain train) {
    final origin = 346.0 + train.platformTrack * 36;
    if (!train.moving) return origin;
    final destination = 346.0 + train.arrivalTrack * 36;
    if (train.progress < 0.15) {
      return origin + (340 - origin) * train.progress / 0.15;
    }
    if (train.progress > 0.85) {
      return 340 + (destination - 340) *
          ((train.progress - 0.85) / 0.15);
    }
    return 340;
  }

  /// Álló vonatok és az ide érkező, úton lévő vonatok együtt.
  int reservedPlatforms(String stationId) => trains.where((train) {
        if (train.moving) return train.nextStationId == stationId;
        return train.currentStationId == stationId;
      }).length;

  double mapPosition(SimTrain train) {
    final from = station(train.currentStationId).mapX;
    if (!train.moving) return from;
    final to = station(train.nextStationId).mapX;
    return from + (to - from) * train.progress;
  }

  void setRunning(bool value) {
    running = value;
    notifyListeners();
  }

  void setAutomatic(bool value) {
    automatic = value;
    if (!value) {
      for (final c in stationControls.values) {
        c.allRed();
      }
    }
    message = value ? 'Automatikus forgalomirányítás.' : 'Kézi forgalomirányítás.';
    notifyListeners();
  }

  void setRiskMode(bool enabled) {
    riskMode = enabled;
    message = enabled
        ? 'Veszélyes üzem: kockázatos indulás ütközést okozhat!'
        : 'Biztonságos üzem: ütköző vágányút tiltva.';
    notifyListeners();
  }

  bool setTurnout(String stationId, RailwaySide side, int track) {
    final c = controls(stationId);
    if (track < 0 || track >= c.station.platforms ||
        c.closedTracks.contains(track) ||
        trains.any((t) => t.moving && t.nextStationId == stationId &&
            opposite(travelSide(t)) == side)) return false;
    c.selectTurnout(side, track);
    c.setSignal(side, SignalKind.entry, false);
    c.setSignal(side, SignalKind.exit, false);
    message = 'Váltó állítva: ' + c.station.name +
        ', ' + (track + 1).toString() + '. vágány.';
    notifyListeners();
    return true;
  }

  bool setSignal(String stationId, RailwaySide side,
      SignalKind kind, bool green) {
    final c = controls(stationId);
    if (green) {
      if (emergency || gameOver || c.closedTracks.contains(c.turnout(side))) {
        return false;
      }
      final adjacent = sections.where((s) =>
          (side == RailwaySide.west
              ? s.to == stationId || s.from == stationId
              : s.from == stationId || s.to == stationId)).toList();
      if (adjacent.isEmpty) return false;
      if (adjacent.every((s) => s.closed || occupying(s) != null)) {
        return false;
      }
    }
    c.setSignal(side, kind, green);
    notifyListeners();
    return true;
  }

  bool setTrackClosed(String stationId, int track, bool closed) {
    final c = controls(stationId);
    if (closed && (trackReserved(stationId, track) ||
        c.westTurnout == track || c.eastTurnout == track)) return false;
    if (closed) {
      c.closedTracks.add(track);
    } else {
      c.closedTracks.remove(track);
    }
    notifyListeners();
    return true;
  }

  void newShift() {
    final fresh = RailwaySimulation();
    trains..clear()..addAll(fresh.trains);
    elapsedSeconds = 0;
    score = 0;
    lives = 3;
    combo = 0;
    collisionCount = 0;
    completedLegs = 0;
    gameOver = false;
    emergency = false;
    running = true;
    message = 'Új szolgálat indult. Balesetmentes közlekedést!';
    for (final c in stationControls.values) {
      c.westTurnout = 0;
      c.eastTurnout = 0;
      c.closedTracks.clear();
      c.allRed();
    }
    for (final s in sections) {
      s.closed = false;
    }
    fresh.dispose();
    notifyListeners();
  }

  /// Csak az opcionális veszélyes játékparancs idézhet elő ütközést.
  bool unsafeDispatch(String number) {
    if (!riskMode || emergency || gameOver) return false;
    final t = train(number);
    if (t.moving || elapsedSeconds < t.readyAt) return false;
    final section = sectionBetween(t.currentStationId, t.nextStationId);
    if (occupying(section) == null) return false;
    collisionCount++;
    lives = math.max(0, lives - 1);
    score = math.max(0, score - 250);
    combo = 0;
    message = 'ÜTKÖZÉS! -1 élet, -250 pont. A forgalom visszaállt.';
    final fresh = RailwaySimulation();
    trains..clear()..addAll(fresh.trains);
    fresh.dispose();
    for (final c in stationControls.values) {
      c.allRed();
    }
    if (lives == 0) {
      gameOver = true;
      running = false;
      message = 'VÉGE A JÁTÉKNAK! Pontszám: ' + score.toString();
    }
    notifyListeners();
    return true;
  }

  void setMultiplier(int value) {
    if (![1, 10, 30, 60].contains(value)) return;
    timeMultiplier = value;
    notifyListeners();
  }

  void setEmergency(bool value) {
    emergency = value;
    if (value) {
      for (final c in stationControls.values) {
        c.allRed();
      }
    }
    message = value ? 'VÉSZLEÁLLÍTÁS!' : 'Forgalom feloldva.';
    notifyListeners();
  }

  bool setSectionClosed(String sectionId, bool value) {
    final section = sections.firstWhere((s) => s.id == sectionId);
    if (value && occupying(section) != null) return false;
    section.closed = value;
    notifyListeners();
    return true;
  }

  bool authorize(String trainNumber) {
    final selected = train(trainNumber);
    if (selected.moving || emergency || gameOver) return false;
    selected.authorized = true;
    notifyListeners();
    return true;
  }

  /// Külső képkockaidő. A belső logika legfeljebb fél szimulációs
  /// másodperces lépésekben halad, így nem ugrik át foglaltsági eseményeket.
  void tick(double realSeconds) {
    if (!running || emergency || gameOver) return;
    var remaining = realSeconds.clamp(0.0, 0.2).toDouble() * timeMultiplier;
    while (remaining > 0) {
      final step = math.min(0.5, remaining);
      _advance(step);
      remaining -= step;
    }
    notifyListeners();
  }

  void _advance(double dt) {
    elapsedSeconds += dt;

    // Előbb a mozgó vonatokat dolgozzuk fel, utána az új indulásokat.
    for (final train in trains.where((t) => t.moving)) {
      final section = sectionBetween(
        train.currentStationId, train.nextStationId);
      train.progress += dt * train.speedKmH / (3600 * section.lengthKm);
      if (train.progress >= 1) {
        train.leg++;
        train.platformTrack = train.arrivalTrack;
        train.moving = false;
        train.progress = 0;
        train.authorized = false;
        train.completedLegs++;
        completedLegs++;
        combo++;
        final reward = 100 + math.min<int>(combo * 10, 100) +
            (train.kind == TrainKind.intercity ? 50 : 0);
        score += reward;
        message = train.number + ' megérkezett. +' + reward.toString() + ' pont';
        train.readyAt = elapsedSeconds + 35;
        // Végállomás: tényleges megállás után indulhat vissza.
        if (train.leg == train.route.length - 1) {
          train.route = train.route.reversed.toList();
          train.leg = 0;
        }
      }
    }

    // Állomási foglaltság és InterCity-elsőbbség: minden indulás egyenként
    // foglal, ezért ugyanarra a pályaszakaszra nincs kettős engedély.
    final candidates = trains.where((t) => !t.moving).toList()
      ..sort((a, b) {
        final ap = a.kind == TrainKind.intercity ? 0 : 1;
        final bp = b.kind == TrainKind.intercity ? 0 : 1;
        return ap.compareTo(bp);
      });

    for (final train in candidates) {
      if (elapsedSeconds < train.readyAt) continue;
      if (!automatic && !train.authorized) continue;
      final section = sectionBetween(
        train.currentStationId, train.nextStationId);
      if (section.closed || occupying(section) != null) continue;
      final side = travelSide(train);
      final source = controls(train.currentStationId);
      final destination = controls(train.nextStationId);
      final entrySide = opposite(side);
      final available = List.generate(destination.station.platforms, (i) => i)
          .where((i) => !destination.closedTracks.contains(i) &&
              !trackReserved(train.nextStationId, i)).toList();
      if (available.isEmpty || source.closedTracks.contains(train.platformTrack)) {
        continue;
      }
      // Automata módban a szabad peront kiválasztja a biztosítóberendezés.
      if (automatic) {
        // A már közeledő vonat bejárati váltóját nem állíthatjuk át.
        if (trains.any((t) => t.moving && t.nextStationId == train.nextStationId
            && opposite(travelSide(t)) == entrySide)) continue;
        source.selectTurnout(side, train.platformTrack);
        destination.selectTurnout(entrySide, available.first);
        source.setSignal(side, SignalKind.exit, true);
        destination.setSignal(entrySide, SignalKind.entry, true);
      }
      final selected = destination.turnout(entrySide);
      if (source.turnout(side) != train.platformTrack ||
          !source.signal(side, SignalKind.exit) ||
          !destination.signal(entrySide, SignalKind.entry) ||
          !available.contains(selected)) continue;
      train.arrivalTrack = selected;
      train.moving = true;
      train.progress = 0;
      train.authorized = false;
      source.setSignal(side, SignalKind.exit, false);
      destination.setSignal(entrySide, SignalKind.entry, false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
