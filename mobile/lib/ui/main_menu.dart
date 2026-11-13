import 'package:flutter/material.dart';
import '../data/session_store.dart';

const _panel = Color(0xFF152E41);
const _mint = Color(0xFF35DDC3);

class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.store, required this.onStart});
  final SessionStore store;
  final VoidCallback onStart;
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final TextEditingController _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = widget.store.playerName != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                children: [
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.train_rounded, size: 72, color: _mint),
                      SizedBox(height: 12),
                      Text('VÁGÁNYMESTER',
                        style: TextStyle(fontSize: 30, fontWeight:
                            FontWeight.w900, letterSpacing: 1.5)),
                      SizedBox(height: 10),
                      Text('FORGALOMIRÁNYÍTÓ SZIMULÁTOR',
                        style: TextStyle(color: _mint,
                            fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(height: 16),
                      Text('Vezesd a vonatokat, állítsd a váltókat, '
                          'óvd a hálózatot és gyűjts pontokat!',
                        style: TextStyle(color: Color(0xFFB3CEDB),
                            height: 1.45)),
                    ],
                  )),
                  const SizedBox(width: 22),
                  Expanded(child: Card(
                    color: _panel,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(loggedIn ? 'Üdv, parancsnok!' : 'VENDÉG BELÉPÉS',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 6),
                          Text(loggedIn ? widget.store.playerName! :
                            'Csak egy nevet kérünk. Nincs regisztráció vagy hitelesítés.',
                            style: const TextStyle(
                                color: Color(0xFFB3CEDB), fontSize: 12)),
                          const SizedBox(height: 14),
                          if (!loggedIn) ...[
                            TextField(
                              controller: _name,
                              maxLength: 20,
                              textInputAction: TextInputAction.done,
                              onSubmitted: _login,
                              decoration: const InputDecoration(
                                labelText: 'Játékos neve',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _login(_name.text),
                              icon: const Icon(Icons.login),
                              label: const Text('BELÉPÉS'),
                            ),
                          ] else ...[
                            FilledButton.icon(
                              onPressed: widget.onStart,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('ÚJ SZOLGÁLAT'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => showLeaderboard(context,
                                  widget.store),
                              icon: const Icon(Icons.emoji_events_outlined),
                              label: const Text('RANGLISTA'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => showSettings(context,
                                  widget.store),
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('BEÁLLÍTÁSOK'),
                            ),
                            TextButton(
                              onPressed: widget.store.signOut,
                              child: const Text('Vendégváltás'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _login(String text) {
    if (text.trim().isNotEmpty) {
      widget.store.enter(text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adj meg egy játékosnevet!')),
      );
    }
  }
}

Future<void> showSettings(BuildContext context, SessionStore store) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('BEÁLLÍTÁSOK'),
      content: SizedBox(
        width: 420,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) => ListView(
            shrinkWrap: true,
            children: [
              SwitchListTile(
                title: const Text('Automatikus irányítás'),
                subtitle: const Text('Automatikus jelző- és váltókezelés'),
                value: store.autoDispatch,
                onChanged: store.setAuto,
              ),
              SwitchListTile(
                title: const Text('Kockázatos játékmód'),
                subtitle: const Text(
                  'Veszélyes indításkor ütközés és életvesztés is lehet'),
                value: store.riskMode,
                onChanged: store.setRisk,
              ),
              SwitchListTile(
                title: const Text('Kezelési tippek'),
                value: store.showHints,
                onChanged: store.setHints,
              ),
              const Divider(),
              const Text('Alapértelmezett sebesség'),
              DropdownButton<int>(
                value: store.speed,
                items: const [1, 10, 30, 60]
                    .map((s) => DropdownMenuItem(
                        value: s, child: Text('$s×')))
                    .toList(),
                onChanged: (value) {
                  if (value != null) store.setSpeed(value);
                },
              ),
              const Text(
                'Az eredmények kizárólag ezen az eszközön maradnak.',
                style: TextStyle(fontSize: 12,
                    color: Color(0xFFB3CEDB)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('KÉSZ')),
      ],
    ),
  );
}

Future<void> showLeaderboard(BuildContext context, SessionStore store) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.emoji_events, color: Color(0xFFFFCC68)),
          SizedBox(width: 10),
          Text('HELYI RANGLISTA'),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 280,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) => store.leaderboard.isEmpty
              ? const Center(child: Text(
                  'Még nincs eredmény. Teljesíts egy szolgálatot!'))
              : ListView.builder(
                  itemCount: store.leaderboard.length,
                  itemBuilder: (context, index) {
                    final entry = store.leaderboard[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text((index + 1).toString())),
                      title: Text(entry.name),
                      subtitle: Text(entry.when.toLocal().toString().split(' ').first),
                      trailing: Text(entry.points.toString() + ' pont',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('BEZÁRÁS')),
      ],
    ),
  );
}
