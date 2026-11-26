import 'package:flutter/material.dart';

import '../models/chords.dart';
import '../theme/app_theme.dart';

/// Diagrama de guitarra: cuerdas, trastes, dedos numerados, cejilla,
/// cuerdas al aire (○) y que no se tocan (×).
class ChordDiagram extends StatelessWidget {
  const ChordDiagram({
    super.key,
    required this.chord,
    this.width = 120,
    this.color = Colors.white,
  });

  final Chord? chord;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = chord;
    final h = width * 1.1;
    if (c == null) return SizedBox(width: width, height: h);
    final shape = GuitarShape.of(c);
    return Semantics(
      label: _describe(shape),
      child: SizedBox(
        width: width,
        height: h,
        child: CustomPaint(painter: _DiagramPainter(shape, color)),
      ),
    );
  }

  static String _describe(GuitarShape s) {
    final parts = <String>[];
    for (var i = 0; i < 6; i++) {
      final f = s.frets[i];
      parts.add(
        'cuerda ${6 - i}: ${f < 0 ? 'no se toca' : (f == 0 ? 'al aire' : 'traste $f')}',
      );
    }
    return 'Diagrama de guitarra. ${s.barre > 0 ? 'Cejilla en traste ${s.barre}. ' : ''}${parts.join(', ')}';
  }
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter(this.shape, this.color);
  final GuitarShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final x0 = w * 0.15, dx = w * 0.14, y0 = h * 0.2, dy = h * 0.155;
    final r = dx * 0.46;
    final base = shape.baseFret;
    final line = Paint()
      ..color = color
      ..strokeWidth = w / 90;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(x0 + i * dx, y0),
        Offset(x0 + i * dx, y0 + 5 * dy),
        line,
      );
    }
    for (var j = 0; j < 6; j++) {
      canvas.drawLine(
        Offset(x0, y0 + j * dy),
        Offset(x0 + 5 * dx, y0 + j * dy),
        j == 0 && base == 1
            ? (Paint()
                ..color = color
                ..strokeWidth = w / 30)
            : line,
      );
    }
    if (base > 1) {
      _text(
        canvas,
        '${base}fr',
        Offset(x0 + 5 * dx + w * 0.05, y0 + dy * 0.5),
        w * 0.09,
        color,
        left: true,
      );
    }

    double yOf(int fret) => y0 + (fret - base + 0.5) * dy;
    final fill = Paint()..color = Brand.crema;

    // Cejilla: una barra con el dedo 1.
    final barre = shape.barre;
    if (barre > 0) {
      final strings = [
        for (var i = 0; i < 6; i++)
          if (shape.frets[i] == barre && shape.fingers[i] == 1) i,
      ];
      if (strings.length > 1) {
        final rect = RRect.fromLTRBR(
          x0 + strings.first * dx - r,
          yOf(barre) - r,
          x0 + strings.last * dx + r,
          yOf(barre) + r,
          Radius.circular(r),
        );
        canvas.drawRRect(rect, fill);
        _text(
          canvas,
          '1',
          Offset(x0 + strings.first * dx, yOf(barre)),
          r * 1.25,
          Brand.azul,
        );
      }
    }
    for (var i = 0; i < 6; i++) {
      final f = shape.frets[i];
      final x = x0 + i * dx;
      if (f < 0) {
        _text(canvas, '×', Offset(x, y0 - dy * 0.55), dy * 0.6, color);
      } else if (f == 0) {
        canvas.drawCircle(
          Offset(x, y0 - dy * 0.55),
          r * 0.62,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = w / 90,
        );
      } else if (!(barre > 0 && f == barre && shape.fingers[i] == 1)) {
        canvas.drawCircle(Offset(x, yOf(f)), r, fill);
        if (shape.fingers[i] > 0) {
          _text(
            canvas,
            '${shape.fingers[i]}',
            Offset(x, yOf(f)),
            r * 1.25,
            Brand.azul,
          );
        }
      }
    }
  }

  void _text(
    Canvas c,
    String s,
    Offset center,
    double size,
    Color color, {
    bool left = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(left ? 0 : tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DiagramPainter old) =>
      old.shape.frets.join() != shape.frets.join() || old.color != color;
}
