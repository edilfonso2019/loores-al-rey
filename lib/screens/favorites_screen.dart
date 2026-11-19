import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../models/playlist.dart';
import '../services/app_state.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'hymn_screen.dart';
import 'shell_screen.dart';

/// Favoritos (Figma 2467:501) con pestañas Listas de culto y Recientes.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos'),
          actions: [
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search_rounded, size: 28),
              onPressed: () => context.read<NavController>().openSearch(),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Brand.dorado,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Favoritos'),
              Tab(text: 'Listas'),
              Tab(text: 'Recientes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_FavoritesTab(), _PlaylistsTab(), _HistoryTab()],
        ),
      ),
    );
  }
}

void _open(BuildContext context, Hymn h) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => HymnScreen(hymn: h)));
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final repo = HymnRepository.instance;
    final items = [for (final id in state.favorites) ?repo.byId(id)];
    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.favorite_border,
        text: 'Aún no tienes favoritos.\nToca el corazón dentro de un himno.',
      );
    }
    return ReorderableListView.builder(
      itemCount: items.length,
      onReorderItem: state.reorderFavorites,
      itemBuilder: (ctx, i) {
        final h = items[i];
        return ListTile(
          key: ValueKey(h.id),
          leading: const Icon(Icons.description, color: Brand.azul, size: 30),
          title: Text('#${h.number} - ${h.title}'),
          subtitle: Text(
            hymnalName(h),
            style: const TextStyle(fontSize: FontSizes.caption),
          ),
          onTap: () => _open(ctx, h),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: i,
                child: const Icon(Icons.drag_handle),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'lista') showAddToPlaylist(ctx, h);
                  if (v == 'quitar') state.toggleFavorite(h.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'lista',
                    child: Text('Agregar a lista de culto'),
                  ),
                  PopupMenuItem(
                    value: 'quitar',
                    child: Text('Quitar de favoritos'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final repo = HymnRepository.instance;
    final items = [for (final id in state.history) ?repo.byId(id)];
    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.history,
        text: 'Aquí verás los himnos que abras.',
      );
    }
    return ListView(
      children: [
        for (final h in items)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('#${h.number} - ${h.title}'),
            subtitle: Text(
              hymnalName(h),
              style: const TextStyle(fontSize: FontSizes.caption),
            ),
            onTap: () => _open(context, h),
          ),
        TextButton(
          onPressed: state.clearHistory,
          child: const Text('Borrar historial'),
        ),
      ],
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.azul,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
        onPressed: () async {
          final name = await promptText(
            context,
            title: 'Nueva lista de culto',
            hint: 'Ej. Culto sábado 15',
          );
          if (name != null) state.createPlaylist(name);
        },
      ),
      body: state.playlists.isEmpty
          ? const _Empty(
              icon: Icons.queue_music,
              text: 'Crea listas de culto para reproducir himnos seguidos.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final pl in state.playlists)
                  ListTile(
                    leading: const Icon(Icons.queue_music, color: Brand.azul),
                    title: Text(pl.name),
                    subtitle: Text('${pl.items.length} himnos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlaylistScreen(playlistId: pl.id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Detalle de una lista de culto: ordenar, reproducir seguido y compartir.
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.playlistId});
  final String playlistId;

  String _shareText(Playlist pl) {
    final repo = HymnRepository.instance;
    final b = StringBuffer('${pl.name}\n\n');
    var i = 1;
    for (final id in pl.items) {
      final h = repo.byId(id);
      if (h != null) {
        b.writeln(
          '${i++}. #${h.number} (${repo.hymnal(h.book)?.sigla}) ${h.title}',
        );
      }
    }
    b.write('\n— App Loores al Rey');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pl = state.playlist(playlistId);
    if (pl == null) return const Scaffold(body: SizedBox.shrink());
    final repo = HymnRepository.instance;
    final hymns = [for (final id in pl.items) repo.byId(id)];
    final player = context.watch<PlayerService>();
    final playingHere = player.queueName == pl.name && player.hasQueue
        ? player.queueIndex
        : -1;
    return Scaffold(
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      appBar: AppBar(
        title: Text(pl.name),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: _shareText(pl), subject: pl.name),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'renombrar') {
                final n = await promptText(
                  context,
                  title: 'Renombrar',
                  initial: pl.name,
                );
                if (n != null) state.renamePlaylist(pl, n);
              } else if (v == 'borrar') {
                if (await confirm(
                      context,
                      'Borrar lista',
                      '¿Borrar "${pl.name}"?',
                      ok: 'Borrar',
                    ) &&
                    context.mounted) {
                  state.deletePlaylist(pl);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
              PopupMenuItem(value: 'borrar', child: Text('Borrar lista')),
            ],
          ),
        ],
      ),
      floatingActionButton: pl.items.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Brand.azul,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Reproducir seguido'),
              onPressed: () => context.read<PlayerService>().playQueue(
                pl.items,
                name: pl.name,
              ),
            ),
      body: pl.items.isEmpty
          ? const _Empty(
              icon: Icons.playlist_add,
              text: 'Lista vacía.\nAgrega himnos desde el menú ⋮ de un himno.',
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: pl.items.length,
              onReorderItem: (a, b) => state.reorderPlaylist(pl, a, b),
              itemBuilder: (ctx, i) {
                final h = hymns[i];
                return Dismissible(
                  key: ValueKey('${pl.id}-${pl.items[i]}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Brand.coral,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => state.removeFromPlaylist(pl, i),
                  child: ListTile(
                    selected: i == playingHere,
                    leading: CircleAvatar(
                      backgroundColor: i == playingHere
                          ? Brand.dorado
                          : Brand.azul,
                      foregroundColor: i == playingHere
                          ? Brand.azul
                          : Colors.white,
                      child: i == playingHere
                          ? const Icon(Icons.volume_up_rounded, size: 20)
                          : Text('${i + 1}'),
                    ),
                    title: Text(
                      h == null ? pl.items[i] : '#${h.number} - ${h.title}',
                    ),
                    subtitle: h == null
                        ? null
                        : Text(
                            hymnalName(h),
                            style: const TextStyle(fontSize: FontSizes.caption),
                          ),
                    onTap: h == null
                        ? null
                        : () => ctx.read<PlayerService>().playQueue(
                            pl.items,
                            index: i,
                            name: pl.name,
                          ),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Brand.gris),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.textoSecundario(context)),
          ),
        ],
      ),
    ),
  );
}
