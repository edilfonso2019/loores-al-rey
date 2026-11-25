import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/hymn.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';

/// Visor de partitura con zoom: usa el archivo descargado o la lee del
/// servidor. Con [allowFullScreen] muestra el botón "Ver completa".
class ScoreView extends StatefulWidget {
  const ScoreView({super.key, required this.hymn, this.allowFullScreen = true});
  final Hymn hymn;
  final bool allowFullScreen;

  @override
  State<ScoreView> createState() => _ScoreViewState();
}

/// Partituras leídas del servidor en esta sesión (las últimas 4), para no
/// volver a descargarlas al abrir la vista completa o cambiar de pestaña.
final Map<String, Uint8List> _cache = {};

void _remember(String key, Uint8List bytes) {
  _cache.remove(key);
  _cache[key] = bytes;
  while (_cache.length > 4) {
    _cache.remove(_cache.keys.first);
  }
}

class _ScoreViewState extends State<ScoreView> {
  PdfControllerPinch? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final media = context.read<MediaService>();
    try {
      final local = media.localFile(widget.hymn, MediaKind.partitura);
      final Future<PdfDocument> doc;
      if (local != null) {
        doc = PdfDocument.openFile(local.path);
      } else {
        final url = media.remoteUrl(widget.hymn, MediaKind.partitura);
        if (url == null) {
          throw const MediaNotAvailable('Partitura aún no disponible.');
        }
        var bytes = _cache[url];
        if (bytes == null) {
          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 25));
          if (res.statusCode == 404) {
            throw const MediaNotAvailable('Partitura aún no disponible.');
          }
          if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
          bytes = Uint8List.fromList(res.bodyBytes);
          _remember(url, bytes);
        }
        doc = PdfDocument.openData(bytes);
      }
      final c = PdfControllerPinch(document: doc);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _loading = false;
      });
    } on MediaNotAvailable catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'No se pudo cargar la partitura.\nRevisa tu conexión o descárgala para verla sin internet.';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ScoreFullScreen(hymn: widget.hymn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off, size: 48, color: Brand.gris),
              const SizedBox(height: Space.s),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: PdfViewPinch(
            controller: _controller!,
            backgroundDecoration: const BoxDecoration(color: Colors.white),
          ),
        ),
        if (widget.allowFullScreen)
          Positioned(
            top: Space.s,
            right: Space.s,
            child: Material(
              color: Brand.azul,
              shape: const StadiumBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _openFullScreen,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Space.m,
                    vertical: Space.s,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_rounded, color: Colors.white),
                      SizedBox(width: Space.xs),
                      Text(
                        'Ver completa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Partitura a pantalla completa: sin barras del sistema, se puede girar el
/// teléfono para verla en horizontal y la pantalla no se apaga.
class ScoreFullScreen extends StatefulWidget {
  const ScoreFullScreen({super.key, required this.hymn});
  final Hymn hymn;

  @override
  State<ScoreFullScreen> createState() => _ScoreFullScreenState();
}

class _ScoreFullScreenState extends State<ScoreFullScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    // La pantalla del himno vuelve a activar el wakelock al mostrarse.
    WakelockPlus.enable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: ScoreView(hymn: widget.hymn, allowFullScreen: false),
          ),
          // Botón para salir, con buen contraste sobre el papel blanco.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.s),
              child: Row(
                children: [
                  Material(
                    color: Brand.azul,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      tooltip: 'Cerrar vista completa',
                      color: Colors.white,
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s,
                        vertical: Space.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Brand.azul.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(Space.m),
                      ),
                      child: Text(
                        '${widget.hymn.number}. ${widget.hymn.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
