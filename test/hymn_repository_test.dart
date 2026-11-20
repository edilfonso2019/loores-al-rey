import 'package:flutter_test/flutter_test.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';
import 'package:loores_al_rey/models/hymn.dart';

import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = HymnRepository.instance;

  setUpAll(() => repo.load(bundle: DiskBundle()));

  test('carga Clásico (activo) y CG (próximamente)', () {
    expect(repo.hymnal('clasico')!.activo, isTrue);
    expect(repo.byBook('clasico'), hasLength(791));
    expect(repo.hymnal('cg')!.activo, isFalse);
    expect(repo.activeHymnals.map((h) => h.id), ['clasico']);
  });

  test('busca por número, título y letra sin tildes', () {
    expect(repo.search('131').first.number, 131);
    expect(
      repo.search('en cristo hallo').first.title.toLowerCase(),
      contains('cristo'),
    );
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

  test('índice por temática: secciones completas y rangos', () {
    final groups = repo.topicIndex('clasico');
    expect(groups.first.name, 'Adoración');
    expect(groups.first.topics.first.name, 'Adoración y alabanza');
    expect(groups.first.topics.first.range, '1–24');
    // Todos los himnos aparecen exactamente una vez.
    final total = groups.fold<int>(0, (a, g) => a + g.hymnCount);
    expect(total, repo.byBook('clasico').length);
    final jesus = groups.firstWhere((g) => g.name == 'Jesucristo');
    expect(
      jesus.topics.map((t) => t.name),
      contains('Su segundo advenimiento'),
    );
  });

  test('índice de un himnario vacío (CG) no falla', () {
    expect(repo.topicIndex('cg').every((g) => g.topics.isEmpty), isTrue);
  });

  test('autor, tonalidad y compás de la partitura', () {
    final h1 = repo.find('clasico', 1)!;
    expect(h1.autorMostrado, 'Juan Hatton');
    expect(h1.tonoLargo, 'Re mayor · 4/4');
    expect(h1.tonoCorto, 'Re M · 4/4');
    expect(repo.find('clasico', 3)!.tonoCorto, 'Si♭ M · 4/4');
    // Partitura sin autor: se muestra "Autor desconocido".
    expect(repo.find('clasico', 541)!.autorMostrado, 'Autor desconocido');
    // Himnos aún sin datos.
    expect(repo.find('clasico', 724)!.hasScoreData, isFalse);
  });

  test('títulos corregidos (541 y sin saltos de línea)', () {
    expect(repo.find('clasico', 541)!.title, 'Oh Señor, procuro en vano');
    expect(
      repo.byBook('clasico').where((h) => h.title.contains('\n')),
      isEmpty,
    );
  });

  test('abreviatura de tonalidades', () {
    expect(Hymn.abreviar('Do sostenido menor'), 'Do♯ m');
    expect(Hymn.abreviar('Mi bemol menor'), 'Mi♭ m');
    expect(Hymn.abreviar(null), isNull);
  });
}
