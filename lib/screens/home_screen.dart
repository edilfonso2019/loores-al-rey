import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/app_state.dart';
import '../widgets/hymn_tile.dart';
import 'hymn_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  int _tab = 0; // 0 = todos, 1 = favoritos, 2 = recientes

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Hymn> _items(AppState state) {
    final repo = HymnRepository.instance;
    switch (_tab) {
      case 1:
        return state.favorites
            .map(repo.byId)
            .whereType<Hymn>()
            .where((h) => h.book == state.book)
            .toList();
      case 2:
        return state.history
            .map(repo.byId)
            .whereType<Hymn>()
            .where((h) => h.book == state.book)
            .toList();
      default:
        return repo.search(state.book, _search.text);
    }
  }

  void _open(Hymn hymn) {
    context.read<AppState>().pushHistory(hymn.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HymnScreen(hymn: hymn)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = _items(state);

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: state.book,
            items: HymnRepository.books.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => v == null ? null : state.setBook(v),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Número, título o letra…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_search.clear),
                        ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => HymnTile(
                      hymn: items[i],
                      onTap: () => _open(items[i]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Himnos'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recientes'),
        ],
      ),
    );
  }
}
