import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../models/hymn.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';

/// Visor de partitura con zoom: usa el archivo descargado o la lee del servidor.
class ScoreView extends StatefulWidget {
  const ScoreView({super.key, required this.hymn});
  final Hymn hymn;

  @override
  State<ScoreView> createState() => _ScoreViewState();
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
        if (url == null) throw const MediaNotAvailable('Partitura aún no disponible.');
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
        if (res.statusCode == 404) throw const MediaNotAvailable('Partitura aún no disponible.');
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        doc = PdfDocument.openData(Uint8List.fromList(res.bodyBytes));
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
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar la partitura.\nRevisa tu conexión o descárgala para verla sin internet.';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_off, size: 48, color: Brand.gris),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return PdfViewPinch(controller: _controller!, backgroundDecoration: const BoxDecoration(color: Colors.white));
  }
}
