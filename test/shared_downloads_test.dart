import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/services/media_service.dart';
import 'package:loores_al_rey/services/shared_downloads.dart';

import 'test_utils.dart';

/// La "otra app" (Acordes IASDMR) tiene descargados el instrumental del 200
/// y la partitura del 1.
class _OtraApp extends SharedDownloads {
  const _OtraApp();
  static const auth = 'pe.looresalrey.acordes.descargas';

  @override
  Future<List<SharedFile>> list() async => const [
    SharedFile(auth, 'clasico/instrumental/200.mp3', 3000000),
    SharedFile(auth, 'clasico/partitura/1.pdf', 150000),
  ];

  @override
  Future<Uint8List?> read(SharedFile f) async => Uint8List.fromList([1, 2, 3]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = HymnRepository.instance;
  late Directory tmp;
  var pedidos = 0;

  setUpAll(() => repo.load(bundle: DiskBundle()));
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loores_compartidas');
    pedidos = 0;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<MediaService> service() async {
    final m = MediaService(
      baseDir: () async => tmp,
      shared: const _OtraApp(),
      client: MockClient((req) async {
        pedidos++;
        return http.Response.bytes(List.filled(10, 7), 200, headers: {'content-length': '10'});
      }),
    );
    await m.init();
    return m;
  }

  test('usa la pista que descargó la otra app, sin internet', () async {
    final m = await service();
    final h = repo.find('clasico', 200)!;
    expect(m.isDownloaded(h, MediaKind.instrumental), isFalse);
    expect(m.isShared(h, MediaKind.instrumental), isTrue);
    expect(m.isOffline(h, MediaKind.instrumental), isTrue);
    expect(
      m.sourceUri(h, MediaKind.instrumental).toString(),
      'content://pe.looresalrey.acordes.descargas/clasico/instrumental/200.mp3',
    );
    expect(await m.checkAvailable(h, MediaKind.instrumental), isTrue);
    expect(pedidos, 0, reason: 'no consulta al servidor');
  });

  test('la partitura compartida se lee por el canal', () async {
    final m = await service();
    final h = repo.find('clasico', 1)!;
    expect(m.isShared(h, MediaKind.partitura), isTrue);
    expect(await m.readShared(h, MediaKind.partitura), [1, 2, 3]);
  });

  test('lo propio tiene prioridad y lo de la otra app no se descarga en lote', () async {
    final m = await service();
    final h200 = repo.find('clasico', 200)!;
    final h201 = repo.find('clasico', 201)!;
    final bajados = await m.downloadAll([h200, h201], MediaKind.instrumental);
    expect(bajados, 1, reason: 'solo el 201; el 200 ya lo tiene la otra app');
    expect(m.isDownloaded(h201, MediaKind.instrumental), isTrue);
    expect(m.isDownloaded(h200, MediaKind.instrumental), isFalse);
    // Si luego se descarga aquí, se usa el archivo propio.
    await m.download(h200, MediaKind.instrumental);
    expect(m.isShared(h200, MediaKind.instrumental), isFalse);
    expect(m.sourceUri(h200, MediaKind.instrumental)!.scheme, 'file');
  });

  test('sin la otra app todo sigue igual', () async {
    final m = MediaService(baseDir: () async => tmp, shared: const SharedDownloads());
    await m.init();
    final h = repo.find('clasico', 200)!;
    expect(m.isShared(h, MediaKind.instrumental), isFalse);
    expect(m.sourceUri(h, MediaKind.instrumental)!.scheme, 'http');
  });
}
