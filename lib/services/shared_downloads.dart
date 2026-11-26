import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Una descarga que tiene la OTRA app de la familia (Loores al Rey o
/// Acordes IASDMR): `ruta` es "himnario/tipo/n.ext".
class SharedFile {
  final String authority;
  final String path;
  final int bytes;
  const SharedFile(this.authority, this.path, this.bytes);

  /// URI que el reproductor puede abrir directamente (content://…).
  Uri get uri => Uri.parse('content://$authority/$path');
}

/// Lee las descargas de la otra app de la familia (ver
/// `android/.../DescargasCompartidas.kt`). Solo funciona entre apps firmadas
/// con la misma llave; si la otra app no está instalada, no hay nada.
class SharedDownloads {
  const SharedDownloads();
  static const _channel = MethodChannel('pe.looresalrey/descargas_compartidas');

  bool get supported => !kIsWeb && Platform.isAndroid;

  Future<List<SharedFile>> list() async {
    if (!supported) return const [];
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>('listar');
      return [
        for (final r in rows ?? const <Map<Object?, Object?>>[])
          SharedFile(r['autoridad']! as String, r['ruta']! as String, (r['bytes']! as num).toInt()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<Uint8List?> read(SharedFile f) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('leer', {'autoridad': f.authority, 'ruta': f.path});
    } catch (_) {
      return null;
    }
  }
}
