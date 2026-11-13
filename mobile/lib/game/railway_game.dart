import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'simulation.dart';

const mapInk = Color(0xFFEAF8FF);
const mapMuted = Color(0xFFA5C2CF);
const mapAccent = Color(0xFF32DDC1);
const mapWarning = Color(0xFFFFC977);

class RailwayGame extends FlameGame with DragCallbacks, ScaleCallbacks {
  RailwayGame({
    required this.simulation,
    required this.onStation,
    required this.onTrain,
  }) : super(
         camera: CameraComponent.withFixedResolution(
           width: 1300,
           height: 650,
         ),
       );

  final RailwaySimulation simulation;
  final void Function(String stationId) onStation;
  final void Function(String trainNumber) onTrain;
  final List<TrainMarker> markers = [];
  double _gestureStartZoom = 1;

  @override
  void onScaleStart(ScaleStartEvent event) {
    super.onScaleStart(event);
    _gestureStartZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateEvent event) {
    camera.viewfinder.zoom =
        (_gestureStartZoom * event.scale).clamp(0.65, 2.8).toDouble();
    // Kétujjas mozgatás: az aktuális zoom mellett természetes tempó.
    pan(event.focalPointDelta / camera.viewfinder.zoom);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isScaling) return;
    pan(event.localDelta / camera.viewfinder.zoom);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2(700, 325);
    await world.add(TrackBackdrop(this));
    for (final station in simulation.stations) {
      await world.add(StationMarker(station, simulation, onStation));
    }
    for (final train in simulation.trains) {
      final marker = TrainMarker(train, simulation, onTrain);
      markers.add(marker);
      await world.add(marker);
    }
  }

  @override
  void update(double dt) {
    simulation.tick(dt);
    super.update(dt);
  }

  void zoom(double factor) {
    camera.viewfinder.zoom =
        (camera.viewfinder.zoom * factor).clamp(0.65, 2.8).toDouble();
  }

  void recenter() {
    camera.viewfinder.position = Vector2(700, 325);
    camera.viewfinder.zoom = 1;
  }

  void pan(Vector2 delta) {
    final next = camera.viewfinder.position - delta;
    camera.viewfinder.position = Vector2(
      next.x.clamp(250.0, 1150.0).toDouble(),
      next.y.clamp(220.0, 430.0).toDouble(),
    );
  }
}

class TrackBackdrop extends PositionComponent {
  TrackBackdrop(this.dispatcher)
    : super(
        position: Vector2.zero(),
        size: Vector2(1400, 650),
        priority: -100,
      );

  final RailwayGame dispatcher;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF0B2131),
    );
    final grid = Paint()
      ..color = const Color(0xFF1B394B)
      ..strokeWidth = 1;
    for (double x = 0; x < 1400; x += 65) {
      canvas.drawLine(Offset(x, 0), Offset(x, 650), grid);
    }
    for (double y = 0; y < 650; y += 65) {
      canvas.drawLine(Offset(0, y), Offset(1400, y), grid);
    }

    _drawText(canvas, 'NYUGATI RÉGIÓ', const Offset(78, 92),
        color: const Color(0xFF6894AD), fontSize: 21, bold: true);
    _drawText(canvas, 'KÖZPONTI FORGALMI HÁLÓZAT',
        const Offset(480, 92), color: mapMuted, fontSize: 20, bold: true);
    _drawText(canvas, 'KELETI RÉGIÓ', const Offset(1093, 92),
        color: const Color(0xFF6894AD), fontSize: 21, bold: true);

    final ballast = Paint()
      ..color = const Color(0xFF35566A)
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(85, 340), const Offset(1325, 340), ballast);

    final track = Paint()
      ..color = const Color(0xFF8DADBE)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(85, 326), const Offset(1325, 326), track);
    canvas.drawLine(const Offset(85, 354), const Offset(1325, 354), track);

    final sleeper = Paint()
      ..color = const Color(0xFFB6CCD5)
      ..strokeWidth = 3;
    for (double x = 90; x <= 1320; x += 24) {
      canvas.drawLine(Offset(x, 321), Offset(x, 359), sleeper);
    }

    // WPF-szerű, többszálú állomási vágányok és kitérők.
    for (final station in dispatcher.simulation.stations) {
      final local = dispatcher.simulation.controls(station.id);
      final x = station.mapX;
      final platform = Paint()
        ..color = const Color(0xFF7EAAB9)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < station.platforms; i++) {
        final y = 346.0 + i * 36;
        final isClosed = local.closedTracks.contains(i);
        platform.color = isClosed
            ? const Color(0xFFF16A74)
            : const Color(0xFF7EAAB9);
        canvas.drawLine(
          Offset(x - 96, y), Offset(x + 96, y), platform);
        canvas.drawLine(
          Offset(x - 145, 340), Offset(x - 96, y), platform);
        canvas.drawLine(
          Offset(x + 96, y), Offset(x + 145, 340), platform);
        _drawText(canvas, (i + 1).toString(),
            Offset(x - 80, y - 28), fontSize: 12, color: mapMuted);
      }
      final westY = 346.0 + local.westTurnout * 36;
      final eastY = 346.0 + local.eastTurnout * 36;
      canvas.drawLine(
        Offset(x - 145, 340), Offset(x - 96, westY),
        Paint()..color = mapAccent..strokeWidth = 5);
      canvas.drawLine(
        Offset(x + 96, eastY), Offset(x + 145, 340),
        Paint()..color = mapAccent..strokeWidth = 5);
      canvas.drawCircle(
        Offset(x - 117, 340), 10,
        Paint()..color = local.westEntry ? mapAccent : const Color(0xFFF16A74));
      canvas.drawCircle(
        Offset(x + 117, 340), 10,
        Paint()..color = local.eastExit ? mapAccent : const Color(0xFFF16A74));
    }

    for (final section in dispatcher.simulation.sections) {
      final from = dispatcher.simulation.station(section.from).mapX;
      final to = dispatcher.simulation.station(section.to).mapX;
      final train = dispatcher.simulation.occupying(section);
      final signalColor = section.closed
          ? const Color(0xFFF46875)
          : train != null
              ? mapWarning
              : mapAccent;
      final middle = (from + to) / 2;
      canvas.drawCircle(
        Offset(middle, 340),
        15,
        Paint()..color = const Color(0xFF102938),
      );
      canvas.drawCircle(
        Offset(middle, 340), 8, Paint()..color = signalColor,
      );
      _drawText(canvas, section.id,
          Offset(middle - 28, 382), color: mapMuted, fontSize: 15);
      _drawText(
        canvas,
        section.closed ? 'VÁGÁNYZÁR' : train == null ? 'SZABAD' : 'FOGLALT',
        Offset(middle - 38, 407),
        color: signalColor,
        fontSize: 14,
        bold: true,
      );
    }

    _drawText(canvas, 'Érintsd meg az állomásokat vagy a vonatokat',
        const Offset(432, 540), color: mapMuted, fontSize: 17);
  }
}

class StationMarker extends PositionComponent with TapCallbacks {
  StationMarker(this.station, this.simulation, this.onSelect)
    : super(
        position: Vector2(station.mapX - 103, 185),
        size: Vector2(206, 120),
        priority: 5,
      );

  final RailwayStation station;
  final RailwaySimulation simulation;
  final void Function(String) onSelect;

  @override
  void onTapDown(TapDownEvent event) => onSelect(station.id);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final border = Paint()
      ..color = mapAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 0, size.x - 4, 99), const Radius.circular(16));
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF173B4C));
    canvas.drawRRect(rect, border);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(15, 14, 34, 34),
          const Radius.circular(8)),
      Paint()..color = const Color(0xFF256F71),
    );
    _drawText(canvas, '⌂', const Offset(24, 15),
        color: mapInk, fontSize: 23, bold: true);
    _drawText(canvas, station.name, const Offset(55, 19),
        color: mapInk, fontSize: 17, bold: true);
    final used = simulation.reservedPlatforms(station.id);
    _drawText(canvas, '$used / ${station.platforms} peron',
        const Offset(55, 55), color: mapMuted, fontSize: 16);
    canvas.drawLine(const Offset(103, 99), const Offset(103, 120),
        Paint()..color = mapAccent..strokeWidth = 3);
    canvas.drawCircle(const Offset(103, 120), 6, Paint()..color = mapAccent);
  }
}

class TrainMarker extends PositionComponent with TapCallbacks {
  TrainMarker(this.train, this.simulation, this.onSelect)
    : super(
        position: Vector2(0, 0),
        size: Vector2(108, 55),
        priority: 20,
      );

  final SimTrain train;
  final RailwaySimulation simulation;
  final void Function(String) onSelect;

  Color get trainColor => switch (train.kind) {
    TrainKind.intercity => const Color(0xFFFFC977),
    TrainKind.freight => const Color(0xFF88A9E4),
    TrainKind.regional => mapAccent,
  };

  @override
  void update(double dt) {
    super.update(dt);
    position.setValues(simulation.mapPosition(train) - 54,
        simulation.mapHeight(train) - 26);
  }

  @override
  void onTapDown(TapDownEvent event) => onSelect(train.number);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final shell = RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 5, 102, 43), const Radius.circular(12));
    canvas.drawRRect(shell, Paint()..color = trainColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 9, 91, 18), const Radius.circular(6)),
      Paint()..color = const Color(0xFF173040),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(13.0 + i * 22.0, 12, 16, 11),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF8DE7ED),
      );
    }
    canvas.drawCircle(const Offset(21, 48), 5,
        Paint()..color = const Color(0xFF0C1A26));
    canvas.drawCircle(const Offset(87, 48), 5,
        Paint()..color = const Color(0xFF0C1A26));
    _drawText(canvas, train.number, const Offset(24, 29),
        color: const Color(0xFF10222F), fontSize: 14, bold: true);
    if (train.moving) {
      canvas.drawCircle(
        const Offset(103, 10), 5, Paint()..color = mapInk,
      );
    }
  }
}

void _drawText(
  Canvas canvas,
  String text,
  Offset offset, {
  Color color = mapInk,
  double fontSize = 16,
  bool bold = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        letterSpacing: 0.2,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  painter.paint(canvas, offset);
}
