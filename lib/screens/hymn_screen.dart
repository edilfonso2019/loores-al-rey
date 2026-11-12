import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/hymn.dart';
import '../services/app_state.dart';
import 'projection_screen.dart';

/// Lectura de un himno: letra con tamaño ajustable (pellizco), favorito,
/// compartir y salto al modo proyección.
class HymnScreen extends StatefulWidget {
  final Hymn hymn;
  const HymnScreen({super.key, required this.hymn});

  @override
  State<HymnScreen> createState() => _HymnScreenState();
}

class _HymnScreenState extends State<HymnScreen> {
  double _startScale = 1;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hymn = widget.hymn;
    final isFav = state.isFavorite(hymn.id);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${hymn.number}'),
        actions: [
          IconButton(
            tooltip: 'Favorito',
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline),
            onPressed: () => state.toggleFavorite(hymn.id),
          ),
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => Share.share(
              '${hymn.number}. ${hymn.title}\n\n${hymn.fullText}\n\n— Loores al Rey',
            ),
          ),
          IconButton(
            tooltip: 'Proyectar',
            icon: const Icon(Icons.cast_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProjectionScreen(hymn: hymn)),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onScaleStart: (_) => _startScale = state.fontScale,
        onScaleUpdate: (d) => state.setFontScale(_startScale * d.scale),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            Text(
              hymn.title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: (text.headlineSmall?.fontSize ?? 24) * state.fontScale,
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0, n = 0; i < hymn.verses.length; i++)
              _VerseBlock(
                verse: hymn.verses[i],
                index: hymn.verses[i].isChorus ? null : ++n,
                scale: state.fontScale,
              ),
          ],
        ),
      ),
    );
  }
}

class _VerseBlock extends StatelessWidget {
  final Verse verse;
  final int? index;
  final double scale;

  const _VerseBlock({required this.verse, required this.index, required this.scale});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!;
    final style = base.copyWith(
      fontSize: (base.fontSize ?? 16) * scale,
      height: 1.5,
      fontStyle: verse.isChorus ? FontStyle.italic : FontStyle.normal,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28 * scale,
            child: Text(
              index == null ? 'Coro' : '$index',
              style: style.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: index == null ? (style.fontSize! * 0.7) : style.fontSize,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(verse.text, style: style)),
        ],
      ),
    );
  }
}
