import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';

/// Elegir qué himnos descargar de un tipo (instrumental, cantado,
/// partitura). Devuelve la lista elegida con Navigator.pop.
class DownloadPickerScreen extends StatefulWidget {
  const DownloadPickerScreen({
    super.key,
    required this.book,
    required this.kind,
  });
  final String book;
  final MediaKind kind;

  @override
  State<DownloadPickerScreen> createState() => _DownloadPickerScreenState();
}

class _DownloadPickerScreenState extends State<DownloadPickerScreen> {
  final _repo = HymnRepository.instance;
  final _query = TextEditingController();
  final Set<String> _selected = {};
  String? _category;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Hymn> get _visible {
    final r = _repo.search(_query.text, book: widget.book, category: _category);
    // La búsqueda pone primero los títulos; aquí conviene el orden numérico.
    return [...r]..sort((a, b) => a.number.compareTo(b.number));
  }

  bool _selectable(MediaService media, Hymn h) =>
      !media.isDownloaded(h, widget.kind) &&
      media.availability(h, widget.kind) != false;

  void _selectVisible(MediaService media, List<Hymn> visible) {
    setState(() {
      for (final h in visible) {
        if (_selectable(media, h)) _selected.add(h.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaService>();
    final secondary = Brand.textoSecundario(context);
    final visible = _visible;
    final selectableVisible = visible.where((h) => _selectable(media, h));
    final allVisibleSelected =
        selectableVisible.isNotEmpty &&
        selectableVisible.every((h) => _selected.contains(h.id));
    final count = _selected.length;
    return Scaffold(
      appBar: AppBar(title: Text('Elegir · ${widget.kind.label}')),
      body: Column(
        children: [
          // ---------- Filtros ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.s,
              Space.gutter,
              0,
            ),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Número o título',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Space.s),
                ),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_query.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              0,
            ),
            child: DropdownButtonFormField<String?>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.list_alt_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Space.s),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todas las temáticas'),
                ),
                for (final c in _repo.categories(book: widget.book))
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (c) => setState(() => _category = c),
            ),
          ),
          // ---------- Seleccionar visibles ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${visible.length} himnos'
                    '${_category != null || _query.text.isNotEmpty ? ' (filtrados)' : ''}',
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: secondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: selectableVisible.isEmpty
                      ? null
                      : () => allVisibleSelected
                            ? setState(() {
                                for (final h in visible) {
                                  _selected.remove(h.id);
                                }
                              })
                            : _selectVisible(media, visible),
                  child: Text(
                    allVisibleSelected
                        ? 'Quitar selección'
                        : 'Seleccionar todos',
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // ---------- Lista ----------
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final h = visible[i];
                final downloaded = media.isDownloaded(h, widget.kind);
                final missing = media.availability(h, widget.kind) == false;
                final enabled = !downloaded && !missing;
                return CheckboxListTile(
                  contentPadding: const EdgeInsets.only(
                    left: Space.gutter,
                    right: Space.xs,
                  ),
                  value: downloaded || _selected.contains(h.id),
                  onChanged: enabled
                      ? (v) => setState(() {
                          v == true
                              ? _selected.add(h.id)
                              : _selected.remove(h.id);
                        })
                      : null,
                  title: Text('${h.number} - ${h.title}'),
                  subtitle: Text(
                    downloaded
                        ? 'Ya descargado'
                        : missing
                        ? 'Aún no disponible'
                        : _repo.categoryName(h),
                    style: TextStyle(
                      fontSize: FontSizes.caption,
                      color: secondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // ---------- Acción principal ----------
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xs,
            Space.gutter,
            Space.s,
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(Space.touch),
            ),
            onPressed: count == 0
                ? null
                : () {
                    final ids = _selected;
                    Navigator.pop(context, [
                      for (final h in _repo.byBook(widget.book))
                        if (ids.contains(h.id)) h,
                    ]);
                  },
            icon: const Icon(Icons.download_rounded),
            label: Text(
              count == 0
                  ? 'Selecciona himnos'
                  : count == 1
                  ? 'Descargar 1 himno'
                  : 'Descargar $count himnos',
            ),
          ),
        ),
      ),
    );
  }
}
