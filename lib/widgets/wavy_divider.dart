import 'package:flutter/material.dart';
import 'dart:math';

class WavyDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double wavelength; // Фиксированная длина волны

  WavyDivider({
    this.height = 20.0,
    this.color = Colors.black,
    this.wavelength = 50.0, // Длина одной волны в пикселях
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _WavyLinePainter(color, wavelength),
      ),
    );
  }
}

class _WavyLinePainter extends CustomPainter {
  final Color color;
  final double wavelength;

  _WavyLinePainter(this.color, this.wavelength);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final amplitude = size.height / 2; // Высота волны

    path.moveTo(0, size.height/2);
    for (double x = 1; x < size.width; x++) {
      path.lineTo(x, amplitude * sin(2 * pi * x / wavelength) + (size.height/2));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}