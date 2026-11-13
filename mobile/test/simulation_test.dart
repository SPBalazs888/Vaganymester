import 'package:flutter_test/flutter_test.dart';
import 'package:vaganymester/game/simulation.dart';

void pump(RailwaySimulation sim) {
  for (var i = 0; i < 10; i++) {
    sim.tick(0.2);
  }
}

void main() {
  test('Három tényleges állomás, négyvágányos központ', () {
    final sim = RailwaySimulation();
    expect(sim.stations.length, 3);
    expect(sim.station('korospatak').platforms, 4);
    expect(sim.sections.length, 2);
    expect(sim.trains.length, 3);
  });

  test('Szemből nem indulhat két vonat ugyanarra a szakaszra', () {
    final sim = RailwaySimulation();
    sim.trains
      ..clear()
      ..addAll([
        SimTrain(
          number: 'A', kind: TrainKind.regional, driver: 'A',
          route: ['fenyvesliget', 'korospatak'], speedKmH: 60,
        ),
        SimTrain(
          number: 'B', kind: TrainKind.regional, driver: 'B',
          route: ['korospatak', 'fenyvesliget'], speedKmH: 60,
        ),
      ]);
    sim.tick(1);
    expect(sim.trains.where((t) => t.moving).length, 1);
    expect(sim.occupying(sim.sections.first), isNotNull);
  });

  test('Vágányzár alatt nem indul új vonat', () {
    final sim = RailwaySimulation();
    expect(sim.setSectionClosed('FV-KP', true), isTrue);
    pump(sim);
    expect(sim.train('S 2412').moving, isFalse);
  });

  test('Foglalt szakaszt nem lehet lezárni', () {
    final sim = RailwaySimulation();
    pump(sim);
    expect(sim.train('S 2412').moving, isTrue);
    expect(sim.setSectionClosed('FV-KP', true), isFalse);
  });

  test('Vészleállítás megállítja az időt és a mozgást', () {
    final sim = RailwaySimulation();
    pump(sim);
    final before = sim.elapsedSeconds;
    final progress = sim.train('S 2412').progress;
    sim.setEmergency(true);
    sim.tick(10);
    expect(sim.elapsedSeconds, before);
    expect(sim.train('S 2412').progress, progress);
  });

  test('Kézi módban beállított váltók és jelzők szükségesek', () {
    final sim = RailwaySimulation();
    sim.setAutomatic(false);
    pump(sim);
    expect(sim.movingCount, 0);
    expect(sim.setTurnout('korospatak', RailwaySide.west, 1), isTrue);
    expect(sim.setSignal('fenyvesliget',
        RailwaySide.east, SignalKind.exit, true), isTrue);
    expect(sim.setSignal('korospatak',
        RailwaySide.west, SignalKind.entry, true), isTrue);
    sim.authorize('S 2412');
    sim.tick(0.1);
    expect(sim.train('S 2412').moving, isTrue);
    expect(sim.train('S 2412').arrivalTrack, 1);
  });

  test('Foglalt vagy lezárt peronra nem állítható váltó', () {
    final sim = RailwaySimulation();
    expect(sim.setTrackClosed('korospatak', 2, true), isTrue);
    expect(sim.setTurnout('korospatak', RailwaySide.east, 2), isFalse);
    expect(sim.setTrackClosed('korospatak', 0, true), isFalse);
  });

  test('Érkezésekért pont jár és folytatódik a vonat útja', () {
    final sim = RailwaySimulation();
    for (var i = 0; i < 70; i++) {
      sim.tick(0.2);
    }
    expect(sim.completedLegs, greaterThan(0));
    expect(sim.score, greaterThanOrEqualTo(100));
    expect(sim.trains.length, 3);
  });

  test('Kockázatos induláskor életvesztés és játék vége', () {
    final sim = RailwaySimulation();
    pump(sim);
    sim.trains.add(SimTrain(
      number: 'X', kind: TrainKind.freight, driver: 'Teszt',
      route: ['korospatak', 'fenyvesliget'], speedKmH: 60,
    ));
    expect(sim.unsafeDispatch('X'), isFalse);
    sim.setRiskMode(true);
    expect(sim.unsafeDispatch('X'), isTrue);
    expect(sim.lives, 2);
    expect(sim.collisionCount, 1);
    pump(sim);
    sim.trains.add(SimTrain(
      number: 'Y', kind: TrainKind.freight, driver: 'Teszt',
      route: ['korospatak', 'fenyvesliget'], speedKmH: 60,
    ));
    expect(sim.unsafeDispatch('Y'), isTrue);
    pump(sim);
    sim.trains.add(SimTrain(
      number: 'Z', kind: TrainKind.freight, driver: 'Teszt',
      route: ['korospatak', 'fenyvesliget'], speedKmH: 60,
    ));
    expect(sim.unsafeDispatch('Z'), isTrue);
    expect(sim.lives, 0);
    expect(sim.gameOver, isTrue);
    expect(sim.running, isFalse);
  });

  test('Új szolgálat visszaállítja az életeket és pontokat', () {
    final sim = RailwaySimulation();
    pump(sim);
    sim.setRiskMode(true);
    sim.trains.add(SimTrain(
      number: 'X', kind: TrainKind.freight, driver: 'Teszt',
      route: ['korospatak', 'fenyvesliget'], speedKmH: 60,
    ));
    sim.unsafeDispatch('X');
    expect(sim.lives, 2);
    sim.newShift();
    expect(sim.lives, 3);
    expect(sim.score, 0);
    expect(sim.collisionCount, 0);
  });
}
