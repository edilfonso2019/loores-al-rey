import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/hymn.dart';

/// Modo proyección: pantalla completa, fondo oscuro, una estrofa a la vez.
/// Pensado para TV / proyector (toca o desliza para avanzar).
class ProjectionScreen extends StatefulWidget {
  final Hymn hymn;
  const ProjectionScreen({super.key, required this.hymn});

  @override
  State<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends State<ProjectionScreen> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < widget.hymn.verses.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _prev() {
    if (_page > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hymn = widget.hymn;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) =>
            d.localPosition.dx < MediaQuery.sizeOf(context).width / 3 ? _prev() : _next(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        '${hymn.number} · ${hymn.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                    ),
                    Text(
                      '${_page + 1}/${hymn.verses.length}',
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: hymn.verses.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final v = hymn.verses[i];
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            v.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: v.isChorus ? const Color(0xFFFFD766) : Colors.white,
                              fontSize: 56,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
