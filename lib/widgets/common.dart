import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// Texto con las coincidencias de [query] resaltadas (sin tildes).
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final q = HymnRepository.normalize(query.trim());
    final norm = HymnRepository.normalize(text);
    if (q.isEmpty || norm.length != text.length || !norm.contains(q)) {
      return Text(text, style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hl = base.copyWith(
      backgroundColor: dark ? Brand.azulMedio : Brand.crema,
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = norm.indexOf(q, start);
      if (i < 0) break;
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(text: text.substring(i, i + q.length), style: hl));
      start = i + q.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Hoja inferior para agregar un himno a una lista de culto (o crear una).
Future<void> showAddToPlaylist(BuildContext context, Hymn hymn) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final state = ctx.watch<AppState>();
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Agregar "${hymn.number} - ${hymn.title}" a…',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Nueva lista de culto'),
              onTap: () async {
                final name = await promptText(ctx, title: 'Nueva lista de culto', hint: 'Ej. Culto sábado 15');
                if (name == null || !ctx.mounted) return;
                final pl = state.createPlaylist(name);
                state.addToPlaylist(pl, hymn.id);
                Navigator.pop(ctx);
                showSnack(context, 'Agregado a "${pl.name}"');
              },
            ),
            for (final pl in state.playlists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(pl.name),
                subtitle: Text('${pl.items.length} himnos'),
                trailing: pl.items.contains(hymn.id) ? const Icon(Icons.check) : null,
                onTap: () {
                  final added = state.addToPlaylist(pl, hymn.id);
                  Navigator.pop(ctx);
                  showSnack(context, added ? 'Agregado a "${pl.name}"' : 'Ya estaba en "${pl.name}"');
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Diálogo con un campo de texto. Devuelve null si se cancela.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? hint,
  String initial = '',
  TextInputType? keyboard,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: keyboard,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Aceptar')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Aceptar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// "131 (C) - Título"
String hymnLabel(Hymn h) {
  final sigla = HymnRepository.instance.hymnal(h.book)?.sigla ?? '';
  return '${h.number} ($sigla) - ${h.title}';
}

String hymnalName(Hymn h) => HymnRepository.instance.hymnal(h.book)?.nombre ?? '';

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
