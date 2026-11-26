import 'package:flutter/material.dart';
import 'package:loores_al_rey/data/chords_repository.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/models/hymn.dart';
import 'package:loores_al_rey/screens/chords_screen.dart';
import 'package:loores_al_rey/services/media_service.dart';
import 'package:loores_al_rey/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Inicio de Acordes IASDMR: buscador de himnos (número, título o letra).
/// Primero los que ya tienen letra con acordes; los demás aparecen como
/// "Próximamente".
class AcordesHome extends StatefulWidget {
  const AcordesHome({super.key});

  @override
  State<AcordesHome> createState() => _AcordesHomeState();
}

class _AcordesHomeState extends State<AcordesHome> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = HymnRepository.instance;
    final chords = ChordsRepository.instance;
    final results = repo.search(_query, book: 'clasico');
    final ready = results.where((h) => chords.has(h.id)).toList();
    final later = results.where((h) => !chords.has(h.id)).take(_query.isEmpty ? 0 : 30).toList();
    final media = context.watch<MediaService>();
    return Scaffold(
      backgroundColor: ChordColors.fondo,
      appBar: AppBar(
        backgroundColor: ChordColors.fondo,
        title: const Text('Acordes IASDMR'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.m, Space.s),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Número o texto del himno',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: ChordColors.panel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            _header('Con letra y acordes (${ready.length})'),
            if (ready.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(Space.l),
                  child: Text('Ningún himno con acordes coincide con la búsqueda.', style: TextStyle(color: ChordColors.tenue)),
                ),
              ),
            SliverList.builder(
              itemCount: ready.length,
              itemBuilder: (context, i) => _HymnTile(hymn: ready[i], media: media),
            ),
            if (later.isNotEmpty) ...[
              _header('Próximamente'),
              SliverList.builder(
                itemCount: later.length,
                itemBuilder: (context, i) => _HymnTile(hymn: later[i], media: media, enabled: false),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.m, Space.xs),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Brand.dorado, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _HymnTile extends StatelessWidget {
  const _HymnTile({required this.hymn, required this.media, this.enabled = true});
  final Hymn hymn;
  final MediaService media;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final offline = media.isOffline(hymn, MediaKind.instrumental);
    final shared = media.isShared(hymn, MediaKind.instrumental);
    return ListTile(
      enabled: enabled,
      minVerticalPadding: Space.xs,
      leading: CircleAvatar(
        backgroundColor: enabled ? Brand.crema : ChordColors.panel,
        foregroundColor: Brand.azul,
        child: Text('${hymn.number}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      title: Text(hymn.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        enabled ? [hymn.tonoCorto, if (offline) (shared ? 'sin conexión · de Loores al Rey' : 'sin conexión')].nonNulls.join(' · ') : hymn.firstLine,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: ChordColors.tenue),
      ),
      trailing: enabled ? const Icon(Icons.queue_music_rounded, color: Brand.dorado) : null,
      onTap: enabled
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChordsScreen(hymn: hymn)))
          : null,
    );
  }
}
