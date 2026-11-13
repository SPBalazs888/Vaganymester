import 'package:flutter_test/flutter_test.dart';
import 'package:vaganymester/game/simulation.dart';

void pump(RailwaySimulation sim) {
  for (var i = 0; i < 10; i++) {
    sim.tick(0.2);
  }
}

void main() {
  test('Három különálló, valódi állomás és két szakasz indul', () {
    final sim = RailwaySimulation();
    expect(sim.stations.length, 3);
    expect(sim.sections.length, 2);
    expect(sim.trains.length, 3);
    expect(sim.trains.every((t) => !t.moving), isTrue);
  });

  test('Ugyanazon a szakaszon nem indulhat el két vonat', () {
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

  test('Kézi üzemnél engedély nélkül nincs indulás', () {
    final sim = RailwaySimulation();
    sim.setAutomatic(false);
    pump(sim);
    expect(sim.movingCount, 0);
    sim.authorize('S 2412');
    sim.tick(0.1);
    expect(sim.train('S 2412').moving, isTrue);
  });

  test('A vonat végállomáson megfordul, nem tűnik el', () {
    final sim = RailwaySimulation();
    sim.trains.removeWhere((t) => t.number != 'S 2412');
    for (var i = 0; i < 60; i++) {
      sim.tick(0.2);
    }
    final train = sim.train('S 2412');
    expect(sim.trains.length, 1);
    expect(train.completedLegs, greaterThan(0));
    expect(sim.completedLegs, greaterThan(0));
  });
}
