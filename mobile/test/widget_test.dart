import 'package:flutter_test/flutter_test.dart';
import 'package:vaganymester/game/simulation.dart';

void main() {
  test('Szimulációs óra 08:00:00-kor indul', () {
    expect(RailwaySimulation().clock, '08:00:00');
  });
}
