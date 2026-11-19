import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/services/media_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = HymnRepository.instance;
  late Directory tmp;

  setUpAll(() => repo.load(bundle: DiskBundle()));
  setUp(() => tmp = Directory.systemTemp.createTempSync('loores_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Servidor falso: solo existen el instrumental y la partitura.
  MediaService service() => MediaService(
    baseDir: () async => tmp,
    client: MockClient((req) async {
      final ok = !req.url.path.contains('cantado');
      if (!ok) return http.Response('no', 404);
      return http.Response.bytes(
        List.filled(1000, 7),
        200,
        headers: {'content-length': '1000'},
      );
    }),
  );

  test('URLs del servidor por himnario', () {
    final m = service();
    final h = repo.find('clasico', 131)!;
    expect(
      m.remoteUrl(h, MediaKind.instrumental),
      'http://192.241.144.242/pista_instrumental/himno_instrumental_131.mp3',
    );
    expect(
      m.remoteUrl(h, MediaKind.partitura),
      'http://192.241.144.242/partitura/himno_partitura_131.pdf',
    );
  });

  test('detecta pistas que aún no existen (404)', () async {
    final m = service();
    await m.init();
    final h = repo.find('clasico', 3)!;
    expect(await m.checkAvailable(h, MediaKind.cantado), isFalse);
    expect(m.availability(h, MediaKind.cantado), isFalse);
    expect(await m.checkAvailable(h, MediaKind.instrumental), isTrue);
    await expectLater(
      m.download(h, MediaKind.cantado),
      throwsA(isA<MediaNotAvailable>()),
    );
  });

  test('descarga, lista y borra archivos offline', () async {
    final m = service();
    await m.init();
    final h = repo.find('clasico', 1)!;
    final f = await m.download(h, MediaKind.instrumental);
    expect(f.lengthSync(), 1000);
    expect(m.isDownloaded(h, MediaKind.instrumental), isTrue);
    expect(m.sourceUri(h, MediaKind.instrumental)!.scheme, 'file');

    // Al reiniciar la app se reconocen las descargas existentes.
    final again = service();
    await again.init();
    expect(again.isDownloaded(h, MediaKind.instrumental), isTrue);
    expect((await again.listDownloads()).single.bytes, 1000);

    await again.delete(h, MediaKind.instrumental);
    expect(again.isDownloaded(h, MediaKind.instrumental), isFalse);
  });

  test('descarga en lote omite las que no existen', () async {
    final m = service();
    await m.init();
    final hymns = repo.byBook('clasico').take(3).toList();
    expect(await m.downloadAll(hymns, MediaKind.cantado), 0);
    expect(await m.downloadAll(hymns, MediaKind.instrumental), 3);
    expect(m.bulkError, isNull);
  });

  test('ubicación: memoria interna o tarjeta SD, y se recuerda', () async {
    final sd = Directory.systemTemp.createTempSync('loores_sd');
    addTearDown(() => sd.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    MediaService withSd() => MediaService(
      baseDir: () async => tmp,
      externalDirs: () async => [
        Directory('/storage/emulated/0/Android/data/x/files'), // no es SD
        sd,
      ],
      client: MockClient(
        (req) async => http.Response.bytes(List.filled(10, 1), 200),
      ),
    );

    final m = withSd();
    await m.init(prefs: prefs);
    expect(m.hasExternal, isTrue);
    expect(m.location, StorageLocation.interna);

    final h1 = repo.find('clasico', 1)!;
    final h2 = repo.find('clasico', 2)!;
    await m.download(h1, MediaKind.instrumental); // interna
    await m.setLocation(StorageLocation.externa);
    await m.download(h2, MediaKind.instrumental); // SD
    expect(m.localFile(h1, MediaKind.instrumental)!.path, startsWith(tmp.path));
    expect(m.localFile(h2, MediaKind.instrumental)!.path, startsWith(sd.path));

    // Al reiniciar: recuerda la SD y encuentra ambas descargas.
    final again = withSd();
    await again.init(prefs: prefs);
    expect(again.location, StorageLocation.externa);
    expect(again.downloadedCount(MediaKind.instrumental, book: 'clasico'), 2);
  });

  test('sin tarjeta SD no se puede elegir externa', () async {
    final m = service();
    await m.init();
    expect(m.hasExternal, isFalse);
    await m.setLocation(StorageLocation.externa);
    expect(m.location, StorageLocation.interna);
  });

  test('borrar todo de un tipo no toca los demás', () async {
    final m = service();
    await m.init();
    final h = repo.find('clasico', 5)!;
    await m.download(h, MediaKind.instrumental);
    await m.download(h, MediaKind.partitura);
    await m.deleteAll(kind: MediaKind.instrumental);
    expect(m.isDownloaded(h, MediaKind.instrumental), isFalse);
    expect(m.isDownloaded(h, MediaKind.partitura), isTrue);
  });
}
