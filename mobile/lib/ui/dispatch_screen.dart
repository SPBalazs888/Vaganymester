import 'dart:ui' show FontFeature;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/railway_game.dart';
import '../game/simulation.dart';

const _surface = Color(0xFF142B3B);
const _muted = Color(0xFFA9C5D2);
const _accent = Color(0xFF35DDC3);

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  late final RailwaySimulation simulation;
  late final RailwayGame game;
  String selectedStationId = 'korospatak';
  String? selectedTrainId;

  @override
  void initState() {
    super.initState();
    simulation = RailwaySimulation();
    game = RailwayGame(
      simulation: simulation,
      onStation: _selectStation,
      onTrain: _selectTrain,
    );
  }

  @override
  void dispose() {
    simulation.dispose();
    super.dispose();
  }

  void _selectStation(String id) {
    setState(() {
      selectedStationId = id;
      selectedTrainId = null;
    });
    if (MediaQuery.sizeOf(context).width < 1030) _showInfoSheet();
  }

  void _selectTrain(String id) {
    setState(() => selectedTrainId = id);
    if (MediaQuery.sizeOf(context).width < 1030) _showInfoSheet();
  }

  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.83,
          child: AnimatedBuilder(
            animation: simulation,
            builder: (context, _) => _details(),
          ),
        ),
      ),
    );
  }

  void _setClosure(TrackSection section, bool closed) {
    final success = simulation.setSectionClosed(section.id, closed);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Foglalt szakaszt nem zárhatsz le. Várd meg a vonatot!',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1030;
            return Column(
              children: [
                AnimatedBuilder(
                  animation: simulation,
                  builder: (context, _) => _toolbar(constraints.maxWidth),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              children: [
                                Positioned.fill(child: GameWidget(game: game)),
                                Positioned(
                                  left: 12,
                                  top: 10,
                                  child: _mapLabel(),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 12,
                                  child: _mapControls(),
                                ),
                                if (!wide)
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: FilledButton.tonalIcon(
                                      onPressed: _showInfoSheet,
                                      icon: const Icon(Icons.tune, size: 18),
                                      label: const Text('Irányítópult'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 302,
                            child: AnimatedBuilder(
                              animation: simulation,
                              builder: (context, _) => _details(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: simulation,
                  builder: (context, _) => _bottomBar(constraints.maxWidth),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _toolbar(double width) {
    final compact = width < 1000;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            const Icon(Icons.train, color: _accent, size: 28),
            const SizedBox(width: 8),
            Text(
              compact ? 'VÁGÁNYMESTER' : 'VÁGÁNYMESTER  /  FORGALMI KÖZPONT',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 14 : 18,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (!compact) ...[
              _statusPill('ÚTON: ${simulation.movingCount}', _accent),
              const SizedBox(width: 8),
            ],
            Text(
              simulation.clock,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 9),
            IconButton.filledTonal(
              tooltip: simulation.running ? 'Szünet' : 'Folytatás',
              onPressed: () =>
                  simulation.setRunning(!simulation.running),
              icon: Icon(
                simulation.running ? Icons.pause : Icons.play_arrow,
              ),
            ),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: simulation.timeMultiplier,
                dropdownColor: _surface,
                items: const [1, 10, 30, 60]
                    .map((speed) => DropdownMenuItem(
                          value: speed,
                          child: Text('${speed}×'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) simulation.setMultiplier(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: simulation.emergency
                  ? 'Vészleállítás feloldása'
                  : 'Központi vészleállítás',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: simulation.emergency
                      ? const Color(0xFF9C3F44)
                      : const Color(0xFF623239),
                  foregroundColor: Colors.white,
                ),
                onPressed: () =>
                    simulation.setEmergency(!simulation.emergency),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: Text(compact ? 'STOP' : 'VÉSZSTOP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapLabel() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xE60C2838),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF285169)),
        ),
        child: const Text(
          'ÉLŐ VASÚTI HÁLÓZAT  •  3 ÁLLOMÁS',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );

  Widget _mapControls() => Row(
        children: [
          _mapButton(Icons.remove, () => game.zoom(0.82)),
          const SizedBox(width: 5),
          _mapButton(Icons.center_focus_strong, game.recenter),
          const SizedBox(width: 5),
          _mapButton(Icons.add, () => game.zoom(1.2)),
        ],
      );

  Widget _mapButton(IconData icon, VoidCallback callback) {
    return Material(
      color: const Color(0xEE1E4054),
      borderRadius: BorderRadius.circular(10),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 19),
        onPressed: callback,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      ),
    );
  }

  Widget _details() {
    final train = selectedTrainId == null
        ? null
        : simulation.train(selectedTrainId!);
    final station = simulation.station(selectedStationId);
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF315265)),
      ),
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            train == null ? 'ÁLLOMÁSI IRÁNYÍTÁS' : 'SZERELVÉNY ADATAI',
            style: const TextStyle(
              color: _accent, fontWeight: FontWeight.w700,
              fontSize: 11, letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          if (train != null) _trainDetails(train)
          else _stationDetails(station),
        ],
      ),
    );
  }

  Widget _trainDetails(SimTrain train) {
    final current = simulation.station(train.currentStationId).name;
    final next = simulation.station(train.nextStationId).name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(train.number, style: const TextStyle(
          fontSize: 27, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(train.typeLabel, style: const TextStyle(color: _muted)),
        const Divider(height: 24),
        _dataRow('Mozdonyvezető', train.driver),
        _dataRow('Indulás', current),
        _dataRow('Következő', next),
        _dataRow('Sebesség',
            train.moving ? '${train.speedKmH.round()} km/h' : '0 km/h'),
        _dataRow('Állapot',
            train.moving ? 'Úton, ${(train.progress * 100).round()}%'
                : 'Állomáson vár'),
        _dataRow('Teljesített szakaszok', '${train.completedLegs}'),
        const SizedBox(height: 12),
        if (!simulation.automatic && !train.moving)
          FilledButton.icon(
            onPressed: () => simulation.authorize(train.number),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Indulás engedélyezése'),
          ),
        TextButton(
          onPressed: () => setState(() => selectedTrainId = null),
          child: const Text('Vissza az állomáshoz'),
        ),
      ],
    );
  }

  Widget _stationDetails(RailwayStation station) {
    final related = simulation.sections
        .where((section) =>
            section.from == station.id || section.to == station.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(station.name, style: const TextStyle(
          fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _dataRow('Foglalt / foglalt érkezési peron',
            '${simulation.reservedPlatforms(station.id)} / ${station.platforms}'),
        _dataRow('Automatizálás',
            simulation.automatic ? 'Bekapcsolva' : 'Kézi üzem'),
        const Divider(height: 25),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatikus forgalom'),
          value: simulation.automatic,
          onChanged: simulation.setAutomatic,
        ),
        const SizedBox(height: 4),
        const Text('Csatlakozó szakaszok',
            style: TextStyle(fontWeight: FontWeight.w700)),
        for (final section in related)
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(section.id),
            subtitle: Text(section.closed ? 'Vágányzár' :
                simulation.occupying(section) == null
                    ? 'Szabad' : 'Vonat halad rajta'),
            value: section.closed,
            onChanged: (value) => _setClosure(section, value),
          ),
        const SizedBox(height: 8),
        const Text(
          'Kézi üzemben a vonatra kattintva adható indulási engedély. '
          'A szakaszfoglaltság és a peronkapacitás mindig védett.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }

  Widget _dataRow(String title, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                fontSize: 11, color: _muted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  Widget _statusPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Text(text, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 11, color: color)),
      );

  Widget _bottomBar(double width) {
    final compact = width < 1000;
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (!compact) ...[
              _statusPill('TELJESÍTETT: ${simulation.completedLegs}', _accent),
              const SizedBox(width: 12),
            ],
            const Text('ÁLLOMÁSOK',
                style: TextStyle(color: _muted, fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: simulation.stations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final station = simulation.stations[index];
                  return ChoiceChip(
                    selected: selectedTrainId == null &&
                        selectedStationId == station.id,
                    label: Text(station.name),
                    onSelected: (_) => _selectStation(station.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
