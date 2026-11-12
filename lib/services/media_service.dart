import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';

/// Tipo de recurso por himno.
enum MediaKind {
  instrumental('Instrumental', 'mp3'),
  cantado('Cantado', 'mp3'),
  partitura('Partitura', 'pdf');

  final String label;
  final String ext;
  const MediaKind(this.label, this.ext);

  bool get isAudio => this != partitura;
}

/// El recurso no existe en el servidor (404) o no hay servidor configurado.
class MediaNotAvailable implements Exception {
  final String message;
  const MediaNotAvailable(this.message);
  @override
  String toString() => message;
}

/// Una descarga guardada en el teléfono.
class DownloadedItem {
  final Hymn hymn;
  final MediaKind kind;
  final File file;
  final int bytes;
  const DownloadedItem(this.hymn, this.kind, this.file, this.bytes);
}

/// URLs del servidor y descargas offline (audio y partituras).
///
/// Archivos en `<documentos>/descargas/<himnario>/<tipo>/<n>.<ext>`.
class MediaService extends ChangeNotifier {
  MediaService({http.Client? client, Future<Directory> Function()? baseDir})
      : _client = client ?? http.Client(),
        _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final http.Client _client;
  final Future<Directory> Function() _baseDir;
  Directory? _root;

  /// Progreso 0..1 de descargas en curso, por clave "libro-n-tipo".
  final Map<String, double> progress = {};

  /// Claves de archivos ya descargados (caché en memoria).
  final Set<String> _downloaded = {};

  /// Descarga masiva en curso.
  bool bulkRunning = false;
  bool _bulkCancel = false;
  int bulkDone = 0;
  int bulkTotal = 0;

  static String key(Hymn h, MediaKind k) => '${h.id}-${k.name}';

  Future<void> init() async {
    final docs = await _baseDir();
    _root = Directory(p.join(docs.path, 'descargas'));
    if (await _root!.exists()) {
      await for (final e in _root!.list(recursive: true)) {
        if (e is! File || e.path.endsWith('.part')) continue;
        final parts = p.split(p.relative(e.path, from: _root!.path));
        if (parts.length != 3) continue;
        final n = p.basenameWithoutExtension(parts[2]);
        _downloaded.add('${parts[0]}-$n-${parts[1]}');
      }
    }
    notifyListeners();
  }

  /// URL remota o null si el himnario no tiene servidor.
  String? remoteUrl(Hymn h, MediaKind k) {
    final s = HymnRepository.instance.hymnal(h.book)?.servidor;
    if (s == null) return null;
    final tpl = switch (k) {
      MediaKind.instrumental => s.instrumental,
      MediaKind.cantado => s.cantado,
      MediaKind.partitura => s.partitura,
    };
    return tpl.replaceAll('{n}', '${h.number}');
  }

  File _fileFor(Hymn h, MediaKind k) =>
      File(p.join(_root!.path, h.book, k.name, '${h.number}.${k.ext}'));

  bool isDownloaded(Hymn h, MediaKind k) => _downloaded.contains(key(h, k));

  bool isDownloading(Hymn h, MediaKind k) => progress.containsKey(key(h, k));

  /// Archivo local si está descargado.
  File? localFile(Hymn h, MediaKind k) =>
      isDownloaded(h, k) && _root != null ? _fileFor(h, k) : null;

  /// URI para reproducir/mostrar: local si existe, si no el servidor.
  Uri? sourceUri(Hymn h, MediaKind k) {
    final f = localFile(h, k);
    if (f != null) return Uri.file(f.path);
    final url = remoteUrl(h, k);
    return url == null ? null : Uri.parse(url);
  }

  /// Descarga un recurso. Lanza [MediaNotAvailable] si no existe.
  Future<File> download(Hymn h, MediaKind k) async {
    final existing = localFile(h, k);
    if (existing != null) return existing;
    final url = remoteUrl(h, k);
    if (url == null) {
      throw const MediaNotAvailable('Este himnario aún no tiene material en el servidor.');
    }
    final id = key(h, k);
    final file = _fileFor(h, k);
    final tmp = File('${file.path}.part');
    progress[id] = 0;
    notifyListeners();
    try {
      final res = await _client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode == 404) {
        throw MediaNotAvailable('${k.label} del himno ${h.number} aún no disponible.');
      }
      if (res.statusCode != 200) {
        throw HttpException('Error del servidor (${res.statusCode}).');
      }
      await tmp.parent.create(recursive: true);
      final sink = tmp.openWrite();
      final total = res.contentLength ?? 0;
      var received = 0;
      var lastNotify = DateTime.now();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0 &&
              DateTime.now().difference(lastNotify).inMilliseconds > 150) {
            progress[id] = received / total;
            lastNotify = DateTime.now();
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && received < total) {
        throw const HttpException('La descarga se interrumpió.');
      }
      await tmp.rename(file.path);
      _downloaded.add(id);
      return file;
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    } finally {
      progress.remove(id);
      notifyListeners();
    }
  }

  Future<void> delete(Hymn h, MediaKind k) async {
    final f = _fileFor(h, k);
    if (await f.exists()) await f.delete();
    _downloaded.remove(key(h, k));
    notifyListeners();
  }

  /// Todas las descargas guardadas, ordenadas por himnario y número.
  Future<List<DownloadedItem>> listDownloads() async {
    final out = <DownloadedItem>[];
    final repo = HymnRepository.instance;
    for (final k in _downloaded) {
      final parts = k.split('-');
      if (parts.length != 3) continue;
      final h = repo.find(parts[0], int.tryParse(parts[1]) ?? -1);
      final kind = MediaKind.values.where((m) => m.name == parts[2]).firstOrNull;
      if (h == null || kind == null) continue;
      final f = _fileFor(h, kind);
      if (await f.exists()) out.add(DownloadedItem(h, kind, f, await f.length()));
    }
    out.sort((a, b) {
      final c = a.hymn.book.compareTo(b.hymn.book);
      if (c != 0) return c;
      final n = a.hymn.number.compareTo(b.hymn.number);
      return n != 0 ? n : a.kind.index.compareTo(b.kind.index);
    });
    return out;
  }

  Future<void> deleteAll() async {
    if (_root != null && await _root!.exists()) await _root!.delete(recursive: true);
    _downloaded.clear();
    notifyListeners();
  }

  /// Descarga en lote (ej. todos los instrumentales). Omite los que no
  /// existen en el servidor. Devuelve cuántos se descargaron.
  Future<int> downloadAll(List<Hymn> hymns, MediaKind kind) async {
    if (bulkRunning) return 0;
    bulkRunning = true;
    _bulkCancel = false;
    final pending = hymns.where((h) => !isDownloaded(h, kind)).toList();
    bulkTotal = pending.length;
    bulkDone = 0;
    var ok = 0;
    notifyListeners();
    try {
      for (final h in pending) {
        if (_bulkCancel) break;
        try {
          await download(h, kind);
          ok++;
        } on MediaNotAvailable {
          // Sigue con el próximo.
        } on SocketException {
          break; // Sin conexión: detener.
        }
        bulkDone++;
        notifyListeners();
      }
    } finally {
      bulkRunning = false;
      notifyListeners();
    }
    return ok;
  }

  void cancelBulk() => _bulkCancel = true;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
