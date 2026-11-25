import 'package:flutter_test/flutter_test.dart';
import 'package:loores_al_rey/models/score_sync.dart';

void main() {
  // Página con 3 renglones (y = 0.2, 0.5, 0.8); la pista toca 2 estrofas.
  const marks = [
    SyncMark(ms: 4000, page: 0, x: 0.10, y: 0.20), // estrofa 1, renglón 1
    SyncMark(ms: 14000, page: 0, x: 0.05, y: 0.50), // renglón 2
    SyncMark(ms: 24000, page: 0, x: 0.05, y: 0.80), // renglón 3
    SyncMark(ms: 34000, page: 0, x: 0.10, y: 0.20), // estrofa 2: vuelve arriba
  ];

  test('antes de la primera marca (introducción) no hay rayita', () {
    expect(ScoreSync.at(marks, const Duration(seconds: 2)), isNull);
    expect(ScoreSync.at(const [], const Duration(seconds: 10)), isNull);
  });

  test('avanza de izquierda a derecha dentro del renglón', () {
    final start = ScoreSync.at(marks, const Duration(milliseconds: 4000))!;
    final middle = ScoreSync.at(marks, const Duration(milliseconds: 9000))!;
    expect(start.x, closeTo(0.10, 1e-9));
    expect(middle.x, closeTo((0.10 + ScoreSync.rightEdge) / 2, 1e-9));
    expect(middle.mark, 0);
    // Alto: 90 % de la distancia al renglón vecino (0.3) centrado en 0.2.
    expect(middle.top, closeTo(0.2 - 0.135, 1e-9));
    expect(middle.bottom, closeTo(0.2 + 0.135, 1e-9));
  });

  test('pasa al siguiente renglón y vuelve arriba en la 2ª estrofa', () {
    expect(ScoreSync.at(marks, const Duration(seconds: 15))!.mark, 1);
    final second = ScoreSync.at(marks, const Duration(seconds: 35))!;
    expect(second.mark, 3);
    expect(second.top, lessThan(0.2));
  });

  test('el último renglón dura hasta el final de la pista', () {
    final c = ScoreSync.at(
      marks,
      const Duration(seconds: 44),
      total: const Duration(seconds: 54),
    )!;
    expect(c.x, closeTo((0.10 + ScoreSync.rightEdge) / 2, 1e-9));
  });

  test('dos marcas en el mismo renglón: la rayita no pasa la segunda', () {
    const row = [
      SyncMark(ms: 0, page: 0, x: 0.1, y: 0.3),
      SyncMark(ms: 10000, page: 0, x: 0.5, y: 0.31),
    ];
    final c = ScoreSync.at(row, const Duration(seconds: 5))!;
    expect(c.x, closeTo(0.3, 1e-9));
  });

  test('ida y vuelta a JSON', () {
    final m = SyncMark.fromJson(marks[1].toJson());
    expect(m.ms, 14000);
    expect(m.y, 0.5);
  });
}
