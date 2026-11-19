import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'hymn_screen.dart';
import 'shell_screen.dart';

/// Buscador (Figma 2487:345): número o texto, temática y himnario.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String? _book; // null = Todos
  String? _category; // null = todas
  int _lastRequest = 0;
  late List<Hymn> _results;

  final _repo = HymnRepository.instance;

  @override
  void initState() {
    super.initState();
    _results = _repo.search('');
  }

  /// Aplica el himnario pedido desde Inicio (botón "Himnario Clásico").
  void _syncWithNav(NavController nav) {
    if (nav.searchRequest == _lastRequest) return;
    _lastRequest = nav.searchRequest;
    _book = nav.searchBook;
    if (_category != null && !_repo.categories(book: _book).contains(_category)) {
      _category = null;
    }
    _results = _repo.search(_ctrl.text, book: _book, category: _category);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _run() {
    setState(() {
      _results = _repo.search(_ctrl.text, book: _book, category: _category);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(Hymn h) {
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HymnScreen(hymn: h)));
  }

  /// Línea de la letra que contiene la búsqueda (o la primera).
  String _snippet(Hymn h) {
    final q = HymnRepository.normalize(_ctrl.text.trim());
    if (q.isNotEmpty && int.tryParse(q) == null) {
      for (final line in h.fullText.split('\n')) {
        if (HymnRepository.normalize(line).contains(q)) return line.trim();
      }
    }
    final lines = h.estrofas.isEmpty ? const <String>[] : h.estrofas.first.split('\n');
    return lines.take(2).map((l) => l.trim()).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    _syncWithNav(context.watch<NavController>());
    final hymnals = _repo.hymnals;
    final cats = _repo.categories(book: _book);
    final query = _ctrl.text;
    return Scaffold(
      body: Column(
        children: [
          _Header(
            controller: _ctrl,
            focus: _focus,
            onChanged: (_) => _run(),
            onClear: () {
              _ctrl.clear();
              _run();
            },
            category: _category,
            categories: cats,
            onCategory: (c) {
              _category = c;
              _run();
            },
            book: _book,
            hymnals: hymnals,
            onBook: (b) {
              _book = b;
              if (_category != null && !_repo.categories(book: b).contains(_category)) {
                _category = null;
              }
              _run();
            },
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No se encontraron himnos para "$query".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _scroll,
                    interactive: true,
                    child: ListView.separated(
                      controller: _scroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _results.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (_, i) {
                        final h = _results[i];
                        return InkWell(
                          onTap: () => _open(h),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HighlightText(
                                  hymnLabel(h),
                                  query: query,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
                                ),
                                const SizedBox(height: 2),
                                HighlightText(
                                  _snippet(h),
                                  query: query,
                                  maxLines: 2,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClear,
    required this.category,
    required this.categories,
    required this.onCategory,
    required this.book,
    required this.hymnals,
    required this.onBook,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String? category;
  final List<String> categories;
  final ValueChanged<String?> onCategory;
  final String? book;
  final List<Hymnal> hymnals;
  final ValueChanged<String?> onBook;

  @override
  Widget build(BuildContext context) {
    const onBlue = TextStyle(color: Colors.white, fontSize: 14);
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            children: [
              // Campo "Número o texto"
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Brand.fondo,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(Icons.search, color: Colors.black87, size: 26),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        onChanged: onChanged,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.black87, fontSize: 18),
                        cursorColor: Brand.azul,
                        decoration: const InputDecoration(
                          hintText: 'Número o texto',
                          hintStyle: TextStyle(color: Colors.black54, fontSize: 18),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (controller.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: onClear,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Temática
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D3DA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: category,
                    isExpanded: true,
                    iconEnabledColor: Brand.azul,
                    dropdownColor: Brand.fondo,
                    style: const TextStyle(color: Brand.azul, fontSize: 14, fontFamily: Brand.fuente),
                    alignment: Alignment.center,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        alignment: Alignment.center,
                        child: Text('Temática (todos)'),
                      ),
                      for (final c in categories)
                        DropdownMenuItem<String?>(
                          value: c,
                          alignment: Alignment.center,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: onCategory,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Buscar en: Todos / Clásico / CG
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RadioGroup<String?>(
                  groupValue: book,
                  onChanged: onBook,
                  child: Row(
                    children: [
                      const Text('Buscar en:', style: onBlue),
                      _radio(null, 'Todos', true),
                      for (final h in hymnals)
                        _radio(h.id, h.activo ? h.nombreCorto : '${h.nombreCorto} (próx.)', h.activo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radio(String? value, String label, bool enabled) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String?>(
          value: value,
          enabled: enabled,
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? Colors.white38 : Colors.white,
          ),
          visualDensity: VisualDensity.compact,
        ),
        Text(
          label,
          style: TextStyle(color: enabled ? Colors.white : Colors.white54, fontSize: 14),
        ),
      ],
    );
  }
}
