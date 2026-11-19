import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/services/media_service.dart';

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
          return http.Response.bytes(List.filled(1000, 7), 200,
              headers: {'content-length': '1000'});
        }),
      );

  test('URLs del servidor por himnario', () {
    final m = service();
    final h = repo.find('clasico', 131)!;
    expect(m.remoteUrl(h, MediaKind.instrumental),
        'http://192.241.144.242/pista_instrumental/himno_instrumental_131.mp3');
    expect(m.remoteUrl(h, MediaKind.partitura),
        'http://192.241.144.242/partitura/himno_partitura_131.pdf');
  });

  test('detecta pistas que aún no existen (404)', () async {
    final m = service();
    await m.init();
    final h = repo.find('clasico', 3)!;
    expect(await m.checkAvailable(h, MediaKind.cantado), isFalse);
    expect(m.availability(h, MediaKind.cantado), isFalse);
    expect(await m.checkAvailable(h, MediaKind.instrumental), isTrue);
    await expectLater(m.download(h, MediaKind.cantado), throwsA(isA<MediaNotAvailable>()));
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
}
