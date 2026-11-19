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

/// Inicio (Figma 2415:988): foto del violín, logo y botones de himnario.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hymnals = HymnRepository.instance.hymnals;
    final size = MediaQuery.sizeOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay(
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: ColoredBox(
        color: Brand.azul,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _Cover(height: (size.height * 0.56).clamp(340, 520)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 28,
                        runSpacing: 16,
                        children: [
                          for (final h in hymnals) _HymnalButton(hymnal: h),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _ContinueSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Foto del Figma (ya incluye "Himnario Loores al Rey").
          Image.asset(
            'assets/images/portada.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            semanticLabel:
                'Himnario Loores al Rey, Asociación Metropolitana UP',
          ),
          // Fundido hacia el azul de marca.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.2, 0.85, 1.0],
                colors: [
                  Color(0x660A245E),
                  Color(0x000A245E),
                  Color(0x000A245E),
                  Brand.azul,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HymnalButton extends StatelessWidget {
  const _HymnalButton({required this.hymnal});
  final Hymnal hymnal;

  @override
  Widget build(BuildContext context) {
    final soon = !hymnal.activo;
    final words = hymnal.nombre.split(' ');
    final label = words.length > 1
        ? '${words.first}\n${words.skip(1).join(' ')}'
        : hymnal.nombre;
    return SizedBox(
      width: 126,
      height: 78,
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
                    style: const TextStyle(
                      color: Brand.azul,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Brand.dorado,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Próximamente',
                  style: TextStyle(
                    color: Brand.azul,
                    fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Brand.dorado),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Continuar donde quedaste',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '#${last.number} · ${last.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
            const SizedBox(height: 12),
            const Text(
              'Recientes',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),
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
