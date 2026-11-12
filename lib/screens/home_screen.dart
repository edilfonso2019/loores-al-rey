import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'shell_screen.dart';

/// Inicio (Figma 2415:988): foto del violín, logo y botones de himnario.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hymnals = HymnRepository.instance.hymnals;
    final size = MediaQuery.sizeOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: Brand.azul,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _Cover(height: (size.height * 0.62).clamp(360, 560)),
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
            semanticLabel: 'Himnario Loores al Rey, Asociación Metropolitana UP',
          ),
          // Fundido hacia el azul de marca.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.2, 0.85, 1.0],
                colors: [Color(0x660A245E), Color(0x000A245E), Color(0x000A245E), Brand.azul],
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
                  style: TextStyle(color: Brand.azul, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
