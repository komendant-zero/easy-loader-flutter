import 'dart:math';
import 'package:flutter/material.dart';

class VhsOverlay extends StatefulWidget {
  final Widget child;
  const VhsOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<VhsOverlay> createState() => _VhsOverlayState();
}

class _VhsOverlayState extends State<VhsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: VhsPainter(_controller.value),
                child: Container(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class VhsPainter extends CustomPainter {
  final double animationValue;
  VhsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(DateTime.now().millisecondsSinceEpoch);

    // 1. Scanlines
    final scanlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    
    for (double i = 0; i < size.height; i += 4) {
      canvas.drawRect(Rect.fromLTWH(0, i, size.width, 1.5), scanlinePaint);
    }

    // 2. Moving tracking noise bar
    double barY = (animationValue * size.height * 1.5) - (size.height * 0.25);
    if (barY > -100 && barY < size.height + 100) {
      final noisePaint = Paint()..color = Colors.white.withOpacity(0.1);
      
      for (int i = 0; i < 40; i++) {
        double yOff = barY + rand.nextDouble() * 120;
        double xOff = rand.nextDouble() * size.width;
        double w = rand.nextDouble() * 250 + 50;
        double h = rand.nextDouble() * 3 + 1;
        canvas.drawRect(Rect.fromLTWH(xOff, yOff, w, h), noisePaint);
      }
    }
    
    // 3. Random full-screen glitch blips
    if (rand.nextDouble() > 0.95) {
       final glitchPaint = Paint()..color = Colors.white.withOpacity(0.04);
       canvas.drawRect(Rect.fromLTWH(0, rand.nextDouble() * size.height, size.width, rand.nextDouble() * 50 + 10), glitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
