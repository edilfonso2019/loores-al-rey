import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'hymn_screen.dart';
import 'shell_screen.dart';
import 'topics_screen.dart';

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
  bool _numeric = true; // En el culto casi siempre se busca por número.
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
    if (_category != null &&
        !_repo.categories(book: _book).contains(_category)) {
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

  /// Cambia entre teclado numérico y de letras (hay que reabrir el teclado).
  void _toggleKeyboard() {
    setState(() => _numeric = !_numeric);
    _focus.unfocus();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _focus.requestFocus();
    });
  }

  /// "Buscar" en el teclado: abre el primer resultado (o el número exacto).
  void _submit(String _) {
    if (_ctrl.text.trim().isEmpty || _results.isEmpty) return;
    _open(_results.first);
  }

  void _open(Hymn h) {
    _focus.unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => HymnScreen(hymn: h)));
  }

  /// Línea de la letra que contiene la búsqueda (o la primera).
  String _snippet(Hymn h) {
    final q = HymnRepository.normalize(_ctrl.text.trim());
    if (q.isNotEmpty && int.tryParse(q) == null) {
      for (final line in h.fullText.split('\n')) {
        if (HymnRepository.normalize(line).contains(q)) return line.trim();
      }
    }
    final lines = h.estrofas.isEmpty
        ? const <String>[]
        : h.estrofas.first.split('\n');
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
            onSubmitted: _submit,
            numeric: _numeric,
            onToggleKeyboard: _toggleKeyboard,
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
              if (_category != null &&
                  !_repo.categories(book: b).contains(_category)) {
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
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          Space.xs,
                          Space.gutter,
                          Space.xxs,
                        ),
                        child: Text(
                          _results.length == 1
                              ? '1 himno'
                              : '${_results.length} himnos',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Brand.textoSecundario(context)),
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _scroll,
                          interactive: true,
                          child: ListView.separated(
                            controller: _scroll,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (_, i) {
                              final h = _results[i];
                              return InkWell(
                                onTap: () => _open(h),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.gutter,
                                    vertical: Space.xs,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      HighlightText(
                                        hymnLabel(h),
                                        query: query,
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontSize: FontSizes.body,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      HighlightText(
                                        _snippet(h),
                                        query: query,
                                        maxLines: 2,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: FontSizes.caption,
                                              color: Brand.textoSecundario(
                                                context,
                                              ),
                                              height: 1.35,
                                            ),
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
    required this.onSubmitted,
    required this.numeric,
    required this.onToggleKeyboard,
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
  final ValueChanged<String> onSubmitted;
  final bool numeric;
  final VoidCallback onToggleKeyboard;
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
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.s,
            Space.gutter,
            Space.xs,
          ),
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
                      padding: EdgeInsets.symmetric(horizontal: Space.s),
                      child: Icon(
                        Icons.search,
                        color: Colors.black87,
                        size: 26,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        keyboardType: numeric
                            ? TextInputType.number
                            : TextInputType.text,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                        ),
                        cursorColor: Brand.azul,
                        decoration: const InputDecoration(
                          hintText: 'Número o texto',
                          hintStyle: TextStyle(
                            color: Colors.black54,
                            fontSize: 18,
                          ),
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
                    // Cambiar teclado: números ↔ letras.
                    TextButton(
                      onPressed: onToggleKeyboard,
                      style: TextButton.styleFrom(
                        foregroundColor: Brand.azul,
                        minimumSize: const Size(52, 40),
                      ),
                      child: Text(
                        numeric ? 'abc' : '123',
                        semanticsLabel: numeric
                            ? 'Teclado de letras'
                            : 'Teclado numérico',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              const SizedBox(height: Space.s),
              // Temática: filtro rápido + acceso al índice completo.
              Row(
                children: [
                  Expanded(
                    child: Container(
                      // 44 px: área táctil cómoda sin perder el aspecto de "píldora".
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: Space.m),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D3DA),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: category,
                          isExpanded: true,
                          iconEnabledColor: Brand.azul,
                          dropdownColor: Brand.fondo,
                          style: const TextStyle(
                            color: Brand.azul,
                            fontSize: FontSizes.small,
                            fontFamily: Brand.fuente,
                          ),
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
                  ),
                  const SizedBox(width: Space.xs),
                  SizedBox(
                    height: 44,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD0D3DA),
                        foregroundColor: Brand.azul,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TopicsScreen(book: book ?? 'clasico'),
                        ),
                      ),
                      icon: const Icon(Icons.list_alt_rounded, size: 20),
                      label: const Text('Índice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xxs),
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
                        _radio(
                          h.id,
                          h.activo ? h.nombreCorto : '${h.nombreCorto} (próx.)',
                          h.activo,
                        ),
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

  /// Radio + texto tocables como una sola zona de 48 px (ley de Fitts):
  /// antes solo respondía el círculo.
  Widget _radio(String? value, String label, bool enabled) {
    return InkWell(
      borderRadius: BorderRadius.circular(Space.l),
      onTap: enabled ? () => onBook(value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Space.touch),
        child: Padding(
          padding: const EdgeInsets.only(right: Space.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<String?>(
                value: value,
                enabled: enabled,
                // El área táctil de 48 px la da la fila completa (InkWell).
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                fillColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.disabled)
                      ? Colors.white38
                      : Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white60,
                  fontSize: FontSizes.small,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
