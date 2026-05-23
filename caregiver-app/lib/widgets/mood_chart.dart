import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;

  const MoodChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _MoodPainter(values: values, labels: labels),
        size: Size.infinite,
      ),
    );
  }
}

class _MoodPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  _MoodPainter({required this.values, required this.labels});

  Color _colorFor(double v) {
    if (v >= 0.6) return AppColors.statusGreen;
    if (v >= 0.4) return AppColors.statusAmber;
    return AppColors.statusRed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const padTop = 12.0;
    const padBottom = 26.0;
    const padLeft = 24.0;
    const padRight = 8.0;

    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = padTop + chartH * (i / 4);
      canvas.drawLine(
          Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
    }

    final stepX = values.length > 1 ? chartW / (values.length - 1) : chartW;

    final pts = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = padLeft + stepX * i;
      final y = padTop + chartH * (1 - values[i].clamp(0.0, 1.0));
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final linePaint = Paint()
      ..color = AppColors.brandDark
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, padTop + chartH)
      ..lineTo(pts.first.dx, padTop + chartH)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.brand.withValues(alpha: 0.08),
    );

    for (int i = 0; i < pts.length; i++) {
      final c = _colorFor(values[i]);
      canvas.drawCircle(pts[i], 5, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], 4, Paint()..color = c);
    }

    final labelStyle = const TextStyle(
        fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500);
    for (int i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(pts[i].dx - tp.width / 2, size.height - padBottom + 6),
      );
    }

    for (final pair in const [(1.0, '😊'), (0.5, '😐'), (0.0, '😟')]) {
      final tp = TextPainter(
        text: TextSpan(
          text: pair.$2,
          style: const TextStyle(fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(2, padTop + chartH * (1 - pair.$1) - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoodPainter old) =>
      old.values != values || old.labels != labels;
}

class MedsComplianceBar extends StatelessWidget {
  final List<bool> values;
  final List<String> labels;

  const MedsComplianceBar({
    super.key,
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        children: List.generate(values.length, (i) {
          final taken = values[i];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: taken
                            ? AppColors.statusGreenSoft
                            : AppColors.statusRedSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: taken
                              ? AppColors.statusGreen.withValues(alpha: 0.3)
                              : AppColors.statusRed.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        taken ? Icons.check_rounded : Icons.close_rounded,
                        color: taken
                            ? AppColors.statusGreen
                            : AppColors.statusRed,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
