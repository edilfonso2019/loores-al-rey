import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';

/// Lee assets directamente del disco (sin necesitar el bundle de Flutter).
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) => File(key).readAsString(encoding: utf8);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = HymnRepository.instance;

  setUpAll(() => repo.load(bundle: _DiskBundle()));

  test('carga Clásico (activo) y CG (próximamente)', () {
    expect(repo.hymnal('clasico')!.activo, isTrue);
    expect(repo.byBook('clasico'), hasLength(791));
    expect(repo.hymnal('cg')!.activo, isFalse);
    expect(repo.activeHymnals.map((h) => h.id), ['clasico']);
  });

  test('busca por número, título y letra sin tildes', () {
    expect(repo.search('131').first.number, 131);
    expect(repo.search('en cristo hallo').first.title.toLowerCase(), contains('cristo'));
    expect(repo.search('Hosánna'), isNotEmpty);
    expect(repo.search('xyzxyz'), isEmpty);
  });

  test('CG inactivo no devuelve resultados', () {
    expect(repo.search('', book: 'cg'), isEmpty);
  });

  test('filtra por temática', () {
    final cat = repo.categories().first;
    final r = repo.search('', category: cat);
    expect(r, isNotEmpty);
    expect(r.every((h) => repo.categoryName(h) == cat), isTrue);
  });

  test('el coro se intercala tras cada estrofa', () {
    final h = repo.byBook('clasico').firstWhere((h) => h.hasChorus);
    final v = h.verses;
    expect(v, hasLength(h.estrofas.length * 2));
    expect(v[1].isChorus, isTrue);
  });

  test('byId resuelve el formato libro-numero', () {
    expect(repo.byId('clasico-131')?.number, 131);
    expect(repo.byId('malformado'), isNull);
  });
}
