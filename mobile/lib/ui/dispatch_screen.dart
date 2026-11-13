import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/railway_game.dart';
import '../game/simulation.dart';
import '../data/session_store.dart';
import 'main_menu.dart';
import 'station_controls_panel.dart';

const _surface = Color(0xFF142B3B);
const _muted = Color(0xFFA9C5D2);
const _accent = Color(0xFF35DDC3);

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({
    super.key,
    required this.store,
    required this.onExit,
  });
  final SessionStore store;
  final VoidCallback onExit;

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  late final RailwaySimulation simulation;
  late final RailwayGame game;
  String selectedStationId = 'korospatak';
  String? selectedTrainId;
  bool _scoreRecorded = false;

  @override
  void initState() {
    super.initState();
    simulation = RailwaySimulation()
      ..setAutomatic(widget.store.autoDispatch)
      ..setRiskMode(widget.store.riskMode)
      ..setMultiplier(widget.store.speed);
    simulation.addListener(_checkGameOver);
    game = RailwayGame(
      simulation: simulation,
      onStation: _selectStation,
      onTrain: _selectTrain,
    );
  }

  @override
  void dispose() {
    simulation.removeListener(_checkGameOver);
    simulation.dispose();
    super.dispose();
  }

  void _checkGameOver() {
    if (!simulation.gameOver || _scoreRecorded) return;
    _scoreRecorded = true;
    widget.store.recordScore(simulation.score);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showGameOver();
    });
  }

  Future<void> _showGameOver() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('VÉGE A SZOLGÁLATNAK'),
        content: Text('Elfogytak az életeid. Pontszám: ' +
            simulation.score.toString() +
            '\nAz eredmény bekerült a helyi ranglistába.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _finishShift(save: false);
            },
            child: const Text('FŐMENÜ'),
          ),
          FilledButton(
            onPressed: () {
              simulation.newShift();
              _scoreRecorded = false;
              setState(() => selectedTrainId = null);
              Navigator.pop(dialogContext);
            },
            child: const Text('ÚJRA'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishShift({bool save = true}) async {
    simulation.setRunning(false);
    if (save && !_scoreRecorded && simulation.score > 0) {
      _scoreRecorded = true;
      await widget.store.recordScore(simulation.score);
    }
    if (mounted) widget.onExit();
  }

  Future<void> _openSettings() async {
    await showSettings(context, widget.store);
    if (!mounted) return;
    simulation.setAutomatic(widget.store.autoDispatch);
    simulation.setRiskMode(widget.store.riskMode);
    simulation.setMultiplier(widget.store.speed);
  }

  void _warn(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _unsafe(String number) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('KOCKÁZATOS UTASÍTÁS'),
        content: const Text('A foglalt szakaszra történő indítás ütközést '
            'okoz, egy életet és 250 pontot veszíthetsz. Folytatod?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('MÉGSE')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('VESZÉLYES INDÍTÁS')),
        ],
      ),
    );
    if (confirm == true && mounted && !simulation.unsafeDispatch(number)) {
      _warn('Veszélyes indítás csak foglalt szakaszon, kész vonattal lehetséges.');
    }
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
    return SizedBox(
      height: 64,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.train, color: _accent, size: 25),
            const SizedBox(width: 6),
            const Text('VÁGÁNYMESTER',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(width: 12),
            _statusPill('★ ' + simulation.score.toString() + ' PONT',
                const Color(0xFFFFCC68)),
            const SizedBox(width: 8),
            _statusPill('♥ ' + simulation.lives.toString() + ' ÉLET',
                const Color(0xFFF16A74)),
            const SizedBox(width: 10),
            Text(simulation.clock, style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(width: 7),
            IconButton.filledTonal(
              tooltip: simulation.running ? 'Szünet' : 'Folytatás',
              onPressed: () =>
                  simulation.setRunning(!simulation.running),
              icon: Icon(simulation.running ? Icons.pause : Icons.play_arrow),
            ),
            DropdownButtonHideUnderline(child: DropdownButton<int>(
              value: simulation.timeMultiplier,
              dropdownColor: _surface,
              items: const [1, 10, 30, 60]
                  .map((s) => DropdownMenuItem(
                    value: s, child: Text(s.toString() + '×'),
                  )).toList(),
              onChanged: (value) {
                if (value != null) {
                  simulation.setMultiplier(value);
                  widget.store.setSpeed(value);
                }
              },
            )),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: simulation.emergency
                    ? const Color(0xFF9C3F44) : const Color(0xFF623239),
                foregroundColor: Colors.white,
              ),
              onPressed: () => simulation.setEmergency(!simulation.emergency),
              icon: const Icon(Icons.warning_amber_rounded, size: 17),
              label: Text(simulation.emergency ? 'FELOLDÁS' : 'VÉSZSTOP'),
            ),
            IconButton(
              tooltip: 'Ranglista',
              onPressed: () => showLeaderboard(context, widget.store),
              icon: const Icon(Icons.emoji_events_outlined),
            ),
            IconButton(
              tooltip: 'Beállítások',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Szolgálat befejezése',
              onPressed: _finishShift,
              icon: const Icon(Icons.home_outlined),
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
          'ÉLŐ HÁLÓZAT  •  3 ÁLLOMÁS  •  PINCH TO ZOOM',
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
        if (!simulation.automatic && !train.moving) ...[
          FilledButton.icon(
            onPressed: () {
              if (!simulation.authorize(train.number)) {
                _warn('Ez a vonat nem indítható.');
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Indulás engedélyezése'),
          ),
          if (simulation.riskMode) ...[
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: () => _unsafe(train.number),
              icon: const Icon(Icons.warning_amber, color: Color(0xFFF16A74)),
              label: const Text('KOCKÁZATOS INDÍTÁS'),
            ),
          ],
        ],
        TextButton(
          onPressed: () => setState(() => selectedTrainId = null),
          child: const Text('Vissza az állomáshoz'),
        ),
      ],
    );
  }

  Widget _stationDetails(RailwayStation station) =>
      StationControlsPanel(
        simulation: simulation,
        station: station,
        onRejected: _warn,
        onAutomatic: (enabled) {
          simulation.setAutomatic(enabled);
          widget.store.setAuto(enabled);
        },
      );

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
            if (widget.store.showHints)
              Text(simulation.message,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            const SizedBox(width: 8),
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
