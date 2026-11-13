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
    RailwayStation('korospatak', 'Kőröspatak', 700),
    RailwayStation('tiszavaros', 'Tiszaváros', 1230),
  ];

  final List<TrackSection> sections = [
    TrackSection('FV-KP', 'fenyvesliget', 'korospatak', 6),
    TrackSection('KP-TV', 'korospatak', 'tiszavaros', 6),
  ];

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
    notifyListeners();
  }

  void setMultiplier(int value) {
    if (![1, 10, 30, 60].contains(value)) return;
    timeMultiplier = value;
    notifyListeners();
  }

  void setEmergency(bool value) {
    emergency = value;
    notifyListeners();
  }

  bool setSectionClosed(String sectionId, bool value) {
    final section = sections.firstWhere((s) => s.id == sectionId);
    if (value && occupying(section) != null) return false;
    section.closed = value;
    notifyListeners();
    return true;
  }

  void authorize(String trainNumber) {
    train(trainNumber).authorized = true;
    notifyListeners();
  }

  /// Külső képkockaidő. A belső logika legfeljebb fél szimulációs
  /// másodperces lépésekben halad, így nem ugrik át foglaltsági eseményeket.
  void tick(double realSeconds) {
    if (!running || emergency) return;
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
        train.moving = false;
        train.progress = 0;
        train.authorized = false;
        train.completedLegs++;
        completedLegs++;
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
      if (reservedPlatforms(train.nextStationId) >=
          station(train.nextStationId).platforms) {
        continue;
      }
      train.moving = true;
      train.progress = 0;
      train.authorized = false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
