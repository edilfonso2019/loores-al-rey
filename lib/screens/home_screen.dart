import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'hymn_screen.dart';
import 'shell_screen.dart';
import 'topics_screen.dart';

/// Inicio (Figma 2415:988): foto del violín, logo y botones de himnario.
///
/// Se adapta al tamaño: en teléfonos y tablets verticales, foto arriba y
/// botones debajo (con ancho máximo); en tablets horizontales, foto a la
/// izquierda y botones a la derecha.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Ancho máximo del contenido bajo la foto (tablets).
  static const _maxContent = 560.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay(
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: ColoredBox(
        color: Brand.azul,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final tablet = box.maxWidth >= 600;
                  final landscape =
                      box.maxWidth >= 840 && box.maxWidth > box.maxHeight;
                  final content = _HomeContent(large: tablet);
                  if (landscape) {
                    final panel = (box.maxWidth * 0.42).clamp(380.0, 520.0);
                    return Row(
                      children: [
                        Expanded(
                          child: _Cover(
                            height: box.maxHeight,
                            fadeToRight: true,
                          ),
                        ),
                        SizedBox(
                          width: panel,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                vertical: Space.l,
                              ),
                              child: content,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final cover = (box.maxHeight * (tablet ? 0.55 : 0.62)).clamp(
                    340.0,
                    760.0,
                  );
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _Cover(height: cover),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxContent,
                            ),
                            child: content,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}

/// Botones de himnario, índice por temática y "Continuar".
class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.large});
  final bool large;

  @override
  Widget build(BuildContext context) {
    final hymnals = HymnRepository.instance.hymnals;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Space.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: large ? Space.xl : 28,
            runSpacing: Space.m,
            children: [
              for (final h in hymnals) _HymnalButton(hymnal: h, large: large),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        const _TopicsCard(),
        const SizedBox(height: Space.s),
        const _ContinueSection(),
        const SizedBox(height: Space.m),
      ],
    );
  }
}

/// Foto del violín con el título dibujado encima (nítido en cualquier
/// pantalla). Se funde hacia el azul de marca abajo o, en horizontal, a la
/// derecha.
class _Cover extends StatelessWidget {
  const _Cover({required this.height, this.fadeToRight = false});
  final double height;
  final bool fadeToRight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        // Tamaño del logo según el ancho, con topes para no exagerar.
        final base = (w * 0.135).clamp(44.0, 96.0);
        const shadow = [
          Shadow(color: Color(0x99000000), blurRadius: 12),
          Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
        ];
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Recorte como en el Figma: cuerpo del violín a la izquierda y
              // la mano un poco a la derecha del centro.
              Image.asset(
                'assets/images/portada_violin.jpg',
                fit: BoxFit.cover,
                alignment: w / height > 1.2
                    ? Alignment.center
                    : const Alignment(-0.35, 0),
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: fadeToRight
                      ? const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.0, 0.75, 1.0],
                          colors: [
                            Color(0x330A245E),
                            Color(0x000A245E),
                            Brand.azul,
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.2, 0.8, 1.0],
                          colors: [
                            Color(0x660A245E),
                            Color(0x000A245E),
                            Color(0x000A245E),
                            Brand.azul,
                          ],
                        ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.08),
                child: Semantics(
                  header: true,
                  label: 'Himnario Loores al Rey, Asociación Metropolitana UP',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Himnario',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: base * 0.48,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                          shadows: shadow,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -base * 0.12),
                        child: Text(
                          'Loores al Rey',
                          style: TextStyle(
                            fontFamily: Brand.fuenteLogo,
                            color: Colors.white,
                            fontSize: base,
                            height: 1.1,
                            shadows: shadow,
                          ),
                        ),
                      ),
                      Text(
                        'Asociación Metropolitana UP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: base * 0.3,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                          shadows: shadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HymnalButton extends StatelessWidget {
  const _HymnalButton({required this.hymnal, this.large = false});
  final Hymnal hymnal;

  /// En tablets los botones son más grandes.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final soon = !hymnal.activo;
    final words = hymnal.nombre.split(' ');
    final label = words.length > 1
        ? '${words.first}\n${words.skip(1).join(' ')}'
        : hymnal.nombre;
    return SizedBox(
      width: large ? 168 : 126,
      height: large ? 96 : 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: soon ? Brand.fondo.withValues(alpha: 0.75) : Brand.fondo,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (soon) {
                    showSnack(context, '${hymnal.nombre}: próximamente.');
                  } else {
                    context.read<NavController>().openSearch(book: hymnal.id);
                  }
                },
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Brand.azul,
                      fontWeight: FontWeight.w700,
                      fontSize: large ? FontSizes.title : FontSizes.body,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (soon)
            Positioned(
              top: -10,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xs,
                  vertical: Space.xxs,
                ),
                decoration: BoxDecoration(
                  color: Brand.dorado,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Próximamente',
                  style: TextStyle(
                    color: Brand.azul,
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Continuar donde quedaste" + recientes: en el culto lo más común es
/// volver al himno que se estaba cantando.
class _ContinueSection extends StatelessWidget {
  const _ContinueSection();

  void _open(BuildContext context, Hymn h) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => HymnScreen(hymn: h)));

  @override
  Widget build(BuildContext context) {
    // Se compara como texto para reconstruir solo si cambian los recientes.
    final recent = context.select<AppState, String>(
      (s) => s.history.take(6).join(','),
    );
    final repo = HymnRepository.instance;
    final hymns = [
      for (final id in recent.split(','))
        if (id.isNotEmpty) ?repo.byId(id),
    ];
    if (hymns.isEmpty) return const SizedBox.shrink();
    final last = hymns.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter + Space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _open(context, last),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.m,
                  Space.s,
                  Space.xs,
                  Space.s,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Brand.dorado),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Continuar donde quedaste',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: FontSizes.caption,
                            ),
                          ),
                          Text(
                            '#${last.number} · ${last.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: FontSizes.body,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hymns.length > 1) ...[
            const SizedBox(height: Space.s),
            const Text(
              'Recientes',
              style: TextStyle(
                color: Colors.white70,
                fontSize: FontSizes.caption,
              ),
            ),
            const SizedBox(height: Space.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final h in hymns.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: Brand.azulMedio,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        label: Text(
                          '#${h.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        tooltip: h.title,
                        onPressed: () => _open(context, h),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Acceso al índice por temática del primer himnario activo.
class _TopicsCard extends StatelessWidget {
  const _TopicsCard();

  @override
  Widget build(BuildContext context) {
    final repo = HymnRepository.instance;
    final active = repo.activeHymnals;
    if (active.isEmpty) return const SizedBox.shrink();
    final book = active.first;
    final groups = repo.topicIndex(book.id);
    final topics = groups.fold<int>(0, (a, g) => a + g.topics.length);
    final examples = groups
        .where((g) => g.name != null)
        .take(3)
        .map((g) => g.name!)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter + Space.xxs),
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Space.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(Space.m),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TopicsScreen(book: book.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.m,
              Space.s,
              Space.xs,
              Space.s,
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt_rounded, color: Brand.dorado),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Índice por temática',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: FontSizes.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        examples.isEmpty
                            ? '$topics temáticas'
                            : '$topics temáticas · $examples…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: FontSizes.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
