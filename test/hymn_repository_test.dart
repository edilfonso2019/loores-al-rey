import 'package:flutter_test/flutter_test.dart';
import 'package:loores_al_rey/data/hymn_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => HymnRepository.instance.load());

  test('carga ambos himnarios', () {
    expect(HymnRepository.instance.byBook('nuevo'), isNotEmpty);
    expect(HymnRepository.instance.byBook('antiguo'), isNotEmpty);
  });

  test('busca por número, título y letra sin tildes', () {
    final repo = HymnRepository.instance;
    expect(repo.search('nuevo', '26').first.number, 26);
    expect(repo.search('nuevo', 'santo'), isNotEmpty);
    expect(repo.search('nuevo', 'labio mio'), isNotEmpty);
    expect(repo.search('nuevo', 'xyzxyz'), isEmpty);
  });

  test('byId resuelve el formato libro-numero', () {
    expect(HymnRepository.instance.byId('antiguo-1')?.title, 'Santo, santo, santo');
    expect(HymnRepository.instance.byId('malformado'), isNull);
  });
}
