import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loores_al_rey/models/chords.dart';
import 'package:loores_al_rey/screens/chords_screen.dart' show ChordLineText;
import 'package:loores_al_rey/widgets/chord_diagram.dart';

void main() {
  group('Chord', () {
    test('entiende los cifrados de las partituras', () {
      final c = Chord.parse('Ab7/C')!;
      expect((c.root, c.quality, c.bass), (8, '7', 0));
      expect(Chord.parse('Em/G')!.quality, 'm');
      expect(Chord.parse('Bb7-9')!.quality, '7');
      expect(Chord.parse('Ab4sus')!.quality, 'sus4');
      expect(Chord.parse('Ddim')!.quality, 'dim');
      expect(Chord.parse('F#m/A')!.root, 6);
      expect(Chord.parse('xyz'), isNull);
    });

    test('nombres: básico, todos, Do Re Mi y capo', () {
      const basico = ChordStyle();
      expect(basico.label('A7/C#'), 'A');
      const todos = ChordStyle(basic: false);
      expect(todos.label('A7/C#'), 'A7/C#');
      const latino = ChordStyle(latin: true, flats: true);
      expect(latino.label('Bbm'), 'Sibm');
      // Capo 1: Lab se toca con forma de Sol.
      const capo1 = ChordStyle(shift: -1);
      expect(capo1.label('Ab'), 'G');
    });

    test('bemoles según la tonalidad', () {
      expect(ChordStyle.keyUsesFlats(Chord.parse('Ab')!), isTrue);
      expect(ChordStyle.keyUsesFlats(Chord.parse('D')!), isFalse);
      expect(ChordStyle.keyUsesFlats(Chord.parse('Dm')!), isTrue);
    });
  });

  group('GuitarShape', () {
    test('formas abiertas con dedos', () {
      final d = GuitarShape.of(Chord.parse('D')!);
      expect(d.frets, [-1, -1, 0, 2, 3, 2]);
      expect(d.fingers, [0, 0, 0, 1, 3, 2]);
      expect(d.isOpen, isTrue);
      expect(GuitarShape.of(Chord.parse('G')!).fingers, [2, 1, 0, 0, 0, 3]);
    });

    test('cejilla en el traste más bajo', () {
      final bm = GuitarShape.of(Chord.parse('Bm')!);
      expect(bm.barre, 2);
      expect(bm.frets, [-1, 2, 4, 4, 3, 2]);
      final ab = GuitarShape.of(Chord.parse('Ab')!);
      expect(ab.barre, 4);
      expect(ab.frets, [4, 6, 6, 5, 4, 4]);
      expect(ab.baseFret, 4);
    });

    test('capo sugerido evita cejillas', () {
      // Himno en Lab: con capo 1 queda en Sol (G, C, D, Em).
      expect(suggestedCapo(['Ab', 'Db', 'Eb', 'Fm']), 1);
      expect(suggestedCapo(['D', 'G', 'A']), 0);
    });
  });

  group('HymnChords (asset real)', () {
    late Map<String, dynamic> himnos;
    setUpAll(() {
      final raw = File('assets/data/acordes.json').readAsStringSync();
      himnos =
          (jsonDecode(raw) as Map<String, dynamic>)['himnos']
              as Map<String, dynamic>;
    });

    test('el 200 tiene letra con acordes y tiempos crecientes', () {
      final h = HymnChords.fromJson(himnos['clasico-200']);
      expect(h.hasLyrics, isTrue);
      expect(h.lines.first.syllables.first.text, 'Pa');
      expect(h.lines.first.syllables.first.chords, ['D']);
      final starts = [for (final l in h.lines) l.start];
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i], greaterThanOrEqualTo(starts[i - 1]));
      }
      expect(h.lines.where((l) => l.stanza == 3), isNotEmpty);
    });

    test('acorde y renglón en un instante', () {
      final h = HymnChords.fromJson(himnos['clasico-200']);
      final t = h.lines[1].start + 0.5;
      expect(h.lineAt(t), 1);
      expect(h.chordIndexAt(t), greaterThanOrEqualTo(0));
      expect(h.lineAt(0), -1); // introducción
      expect(h.timeline.last.$2, 'D'); // termina en la tónica
    });

    // Celular vertical (360 px) y horizontal (800 px), letra grande y chica:
    // ningún renglón de ningún himno debe desbordar.
    for (final width in [360.0, 800.0]) {
      testWidgets('letra con acordes sin desbordes a $width px', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final id in himnos.keys) {
          final h = HymnChords.fromJson(himnos[id]);
          for (final fontSize in [18.0, 34.0]) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: ListView(
                    children: [
                      for (final l in h.lines)
                        ChordLineText(line: l, style: const ChordStyle(basic: false), fontSize: fontSize, sung: 3),
                    ],
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull, reason: '$id a $fontSize');
          }
        }
      });
    }

    testWidgets('diagramas de todos los acordes se dibujan', (tester) async {
      final all = <String>{};
      for (final j in himnos.values) {
        for (final (_, c) in HymnChords.fromJson(j).timeline) {
          all.add(c);
        }
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Wrap(
                children: [
                  for (final c in all) ChordDiagram(chord: Chord.parse(c), width: 60),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ChordDiagram), findsNWidgets(all.length));
    });
  });
}
