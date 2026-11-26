import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import 'shared_downloads.dart';

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

/// Dónde se guardan las descargas nuevas.
enum StorageLocation {
  interna('Memoria interna'),
  externa('Tarjeta SD');

  final String label;
  const StorageLocation(this.label);
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
/// Archivos en `<raíz>/descargas/<himnario>/<tipo>/<n>.<ext>`, donde la raíz
/// es la memoria interna de la app o su carpeta en la tarjeta SD. Cada
/// descarga recuerda dónde quedó: cambiar de ubicación no pierde las previas.
///
/// Si la otra app de la familia (Loores al Rey / Acordes IASDMR) ya descargó
/// un recurso, se usa ese ([isShared]) y no se descarga dos veces.
class MediaService extends ChangeNotifier {
  MediaService({
    http.Client? client,
    Future<Directory> Function()? baseDir,
    Future<List<Directory>?> Function()? externalDirs,
    SharedDownloads? shared,
  }) : _client = client ?? http.Client(),
       _sharedSource = shared ?? const SharedDownloads(),
       _baseDir = baseDir ?? getApplicationDocumentsDirectory,
       _externalDirs = externalDirs ?? _defaultExternalDirs;

  final http.Client _client;
  final Future<Directory> Function() _baseDir;
  final Future<List<Directory>?> Function() _externalDirs;
  final SharedDownloads _sharedSource;

  /// Descargas de la otra app de la familia: clave → archivo.
  final Map<String, SharedFile> _shared = {};
  Directory? _internalRoot;
  Directory? _externalRoot;
  SharedPreferences? _prefs;
  static const _kLocation = 'downloadLocation';

  /// Ubicación elegida para las descargas nuevas.
  StorageLocation location = StorageLocation.interna;

  /// Progreso 0..1 de descargas en curso, por clave "libro-n-tipo".
  final Map<String, double> progress = {};

  /// Descargas guardadas: clave → archivo (en la ubicación donde quedó).
  final Map<String, File> _downloaded = {};

  /// Descarga masiva en curso.
  bool bulkRunning = false;
  bool _bulkCancel = false;
  int bulkDone = 0;
  int bulkTotal = 0;
  MediaKind? bulkKind;

  static String key(Hymn h, MediaKind k) => '${h.id}-${k.name}';

  static Future<List<Directory>?> _defaultExternalDirs() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    return getExternalStorageDirectories();
  }

  /// true si hay tarjeta SD (u otro almacenamiento extraíble) disponible.
  bool get hasExternal => _externalRoot != null;

  Directory? get _targetRoot =>
      location == StorageLocation.externa && _externalRoot != null
      ? _externalRoot
      : _internalRoot;

  /// false si el dispositivo no permite guardar archivos (p. ej. web).
  bool get canDownload => _targetRoot != null;

  /// Ruta de la carpeta de descargas de [l] (para mostrarla), o null.
  String? locationPath(StorageLocation l) =>
      (l == StorageLocation.interna ? _internalRoot : _externalRoot)?.path;

  Future<void> init({SharedPreferences? prefs}) async {
    _prefs = prefs;
    try {
      final docs = await _baseDir();
      _internalRoot = Directory(p.join(docs.path, 'descargas'));
    } catch (_) {
      // Sin carpeta de documentos (web o error del sistema): solo streaming.
    }
    try {
      // getExternalStorageDirectories devuelve primero el almacenamiento
      // "emulado" (que en realidad es memoria interna) y luego la SD.
      final dirs = await _externalDirs() ?? const <Directory>[];
      final sd = dirs.where((d) => !d.path.startsWith('/storage/emulated/'));
      if (sd.isNotEmpty) {
        _externalRoot = Directory(p.join(sd.first.path, 'descargas'));
      }
    } catch (_) {
      // Sin almacenamiento externo.
    }
    final saved = prefs?.getString(_kLocation);
    location = StorageLocation.values.firstWhere(
      (l) => l.name == saved,
      orElse: () => StorageLocation.interna,
    );
    for (final root in [?_internalRoot, ?_externalRoot]) {
      await _scan(root);
    }
    await refreshShared();
    notifyListeners();
  }

  /// Vuelve a consultar qué tiene descargado la otra app (al abrir la app o
  /// al volver a ella, por si mientras tanto descargó algo).
  Future<void> refreshShared() async {
    final files = await _sharedSource.list();
    _shared.clear();
    for (final f in files) {
      final parts = f.path.split('/');
      if (parts.length != 3) continue;
      final n = p.basenameWithoutExtension(parts[2]);
      _shared['${parts[0]}-$n-${parts[1]}'] = f;
    }
    notifyListeners();
  }

  /// true si NO está descargado aquí pero sí en la otra app de la familia.
  bool isShared(Hymn h, MediaKind k) =>
      !isDownloaded(h, k) && _shared.containsKey(key(h, k));

  /// Descargado aquí o en la otra app: se puede usar sin internet.
  bool isOffline(Hymn h, MediaKind k) =>
      isDownloaded(h, k) || _shared.containsKey(key(h, k));

  /// Contenido de un recurso de la otra app (para la partitura PDF).
  Future<Uint8List?> readShared(Hymn h, MediaKind k) async {
    final f = _shared[key(h, k)];
    return f == null ? null : _sharedSource.read(f);
  }

  /// Registra los archivos ya descargados en [root].
  Future<void> _scan(Directory root) async {
    if (!await root.exists()) return;
    await for (final e in root.list(recursive: true)) {
      if (e is! File || e.path.endsWith('.part')) continue;
      final parts = p.split(p.relative(e.path, from: root.path));
      if (parts.length != 3) continue;
      final n = p.basenameWithoutExtension(parts[2]);
      _downloaded['${parts[0]}-$n-${parts[1]}'] = e;
    }
  }

  /// Cambia dónde se guardan las descargas NUEVAS.
  Future<void> setLocation(StorageLocation l) async {
    if (l == StorageLocation.externa && !hasExternal) return;
    location = l;
    await _prefs?.setString(_kLocation, l.name);
    notifyListeners();
  }

  /// Cuántos recursos de [kind] están descargados (de [book] si se indica).
  int downloadedCount(MediaKind kind, {String? book}) => _downloaded.keys
      .where(
        (k) =>
            k.endsWith('-${kind.name}') &&
            (book == null || k.startsWith('$book-')),
      )
      .length;

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

  /// Dónde se guardará una descarga NUEVA.
  File _newFileFor(Hymn h, MediaKind k) =>
      File(p.join(_targetRoot!.path, h.book, k.name, '${h.number}.${k.ext}'));

  bool isDownloaded(Hymn h, MediaKind k) => _downloaded.containsKey(key(h, k));

  bool isDownloading(Hymn h, MediaKind k) => progress.containsKey(key(h, k));

  /// Archivo local si está descargado.
  File? localFile(Hymn h, MediaKind k) => _downloaded[key(h, k)];

  /// URI para reproducir/mostrar: local si existe, luego la descarga de la
  /// otra app y por último el servidor.
  Uri? sourceUri(Hymn h, MediaKind k) {
    final f = localFile(h, k);
    if (f != null) return Uri.file(f.path);
    final shared = _shared[key(h, k)];
    if (shared != null) return shared.uri;
    final url = remoteUrl(h, k);
    return url == null ? null : Uri.parse(url);
  }

  /// Mensaje para recursos que el servidor aún no tiene (404).
  static String notAvailableMessage(Hymn h, MediaKind k) => switch (k) {
    MediaKind.cantado => 'Pista cantada aún no disponible.',
    MediaKind.instrumental => 'Pista instrumental aún no disponible.',
    MediaKind.partitura => 'Partitura aún no disponible.',
  };

  /// true = existe, false = el servidor no la tiene (404), null = sin
  /// comprobar o sin conexión.
  final Map<String, bool> _available = {};
  final Map<String, Future<bool?>> _checking = {};

  bool? availability(Hymn h, MediaKind k) =>
      isOffline(h, k) ? true : _available[key(h, k)];

  /// Consulta al servidor (HEAD) si el recurso existe. Cachea la respuesta.
  Future<bool?> checkAvailable(Hymn h, MediaKind k) {
    final id = key(h, k);
    if (isOffline(h, k)) return Future.value(true);
    if (_available.containsKey(id)) return Future.value(_available[id]);
    return _checking[id] ??= () async {
      try {
        final url = remoteUrl(h, k);
        if (url == null) {
          _available[id] = false;
          return false;
        }
        final res = await _client
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) _available[id] = true;
        if (res.statusCode == 404) _available[id] = false;
        // Otro código (500, 502…): hay internet pero el servidor falla.
        if (res.statusCode != 200 && res.statusCode != 404) {
          _serverErrors.add(id);
        } else {
          _serverErrors.remove(id);
        }
        return _available[id];
      } catch (_) {
        return null; // Sin conexión: no se cachea.
      } finally {
        _checking.remove(id);
        notifyListeners();
      }
    }();
  }

  final Set<String> _serverErrors = {};

  /// true si la última consulta llegó al servidor pero este respondió con
  /// un error (no es falta de internet).
  bool serverFailed(Hymn h, MediaKind k) => _serverErrors.contains(key(h, k));

  final Set<String> _prefetched = {};

  /// Comprueba la disponibilidad una sola vez por sesión (para la UI).
  void prefetchAvailability(Hymn h, MediaKind k) {
    final id = key(h, k);
    if (isOffline(h, k) ||
        _available.containsKey(id) ||
        !_prefetched.add(id)) {
      return;
    }
    Future.microtask(() => checkAvailable(h, k));
  }

  final Map<String, Future<File>> _inflight = {};

  /// Descarga un recurso. Lanza [MediaNotAvailable] si no existe.
  /// Si ya se está descargando, devuelve la misma descarga.
  Future<File> download(Hymn h, MediaKind k) {
    final existing = localFile(h, k);
    if (existing != null) return Future.value(existing);
    final id = key(h, k);
    // Ojo: el callback no debe devolver el Future (se esperaría a sí mismo).
    return _inflight[id] ??= _download(h, k).whenComplete(() {
      _inflight.remove(id);
    });
  }

  Future<File> _download(Hymn h, MediaKind k) async {
    if (!canDownload) {
      throw const MediaNotAvailable(
        'Las descargas no están disponibles en este dispositivo.',
      );
    }
    final url = remoteUrl(h, k);
    if (url == null) {
      throw const MediaNotAvailable(
        'Este himnario aún no tiene material en el servidor.',
      );
    }
    final id = key(h, k);
    final file = _newFileFor(h, k);
    final tmp = File('${file.path}.part');
    progress[id] = 0;
    notifyListeners();
    try {
      final res = await _client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        _available[id] = false;
        throw MediaNotAvailable(notAvailableMessage(h, k));
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
        // Si el servidor deja de enviar datos 30 s, se corta.
        await for (final chunk in res.stream.timeout(
          const Duration(seconds: 30),
        )) {
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
      _downloaded[id] = file;
      _available[id] = true;
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
    final f = _downloaded.remove(key(h, k));
    if (f != null && await f.exists()) await f.delete();
    notifyListeners();
  }

  /// Todas las descargas guardadas, ordenadas por himnario y número.
  Future<List<DownloadedItem>> listDownloads() async {
    final out = <DownloadedItem>[];
    final repo = HymnRepository.instance;
    for (final MapEntry(key: k, value: f) in _downloaded.entries) {
      final parts = k.split('-');
      if (parts.length != 3) continue;
      final h = repo.find(parts[0], int.tryParse(parts[1]) ?? -1);
      final kind = MediaKind.values
          .where((m) => m.name == parts[2])
          .firstOrNull;
      if (h == null || kind == null) continue;
      if (await f.exists()) {
        out.add(DownloadedItem(h, kind, f, await f.length()));
      }
    }
    out.sort((a, b) {
      final c = a.hymn.book.compareTo(b.hymn.book);
      if (c != 0) return c;
      final n = a.hymn.number.compareTo(b.hymn.number);
      return n != 0 ? n : a.kind.index.compareTo(b.kind.index);
    });
    return out;
  }

  /// Borra todas las descargas, o solo las de [kind].
  Future<void> deleteAll({MediaKind? kind}) async {
    final keys = _downloaded.keys
        .where((k) => kind == null || k.endsWith('-${kind.name}'))
        .toList();
    for (final k in keys) {
      final f = _downloaded.remove(k);
      try {
        if (f != null && await f.exists()) await f.delete();
      } catch (_) {
        // Archivo ya borrado o SD retirada: se ignora.
      }
    }
    notifyListeners();
  }

  /// Motivo por el que se detuvo la última descarga en lote (o null).
  String? bulkError;

  /// Descarga en lote (ej. todos los instrumentales). Omite los que no
  /// existen en el servidor y se detiene si se pierde la conexión.
  /// Devuelve cuántos se descargaron.
  Future<int> downloadAll(List<Hymn> hymns, MediaKind kind) async {
    if (bulkRunning) return 0;
    bulkRunning = true;
    bulkKind = kind;
    bulkError = null;
    _bulkCancel = false;
    // Lo que ya tiene la otra app no se vuelve a descargar.
    final pending = hymns.where((h) => !isOffline(h, kind)).toList();
    bulkTotal = pending.length;
    bulkDone = 0;
    var ok = 0;
    var failures = 0;
    notifyListeners();
    try {
      for (final h in pending) {
        if (_bulkCancel) break;
        try {
          await download(h, kind);
          ok++;
          failures = 0;
        } on MediaNotAvailable {
          // No existe en el servidor: sigue con el próximo.
        } on SocketException {
          bulkError = 'Se perdió la conexión.';
          break;
        } on http.ClientException {
          bulkError = 'Se perdió la conexión.';
          break;
        } on TimeoutException {
          bulkError = 'El servidor no responde.';
          break;
        } catch (_) {
          // Error puntual del servidor: se omite, salvo que se repita mucho.
          if (++failures >= 5) {
            bulkError = 'El servidor está fallando. Inténtalo más tarde.';
            break;
          }
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
