import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';

class SafetyScoreWidget extends StatefulWidget {
  final int score; // 0 a 100
  final double size;
  final bool showLabel;
  final String? label;

  const SafetyScoreWidget({
    Key? key,
    required this.score,
    this.size = 120,
    this.showLabel = true,
    this.label,
  }) : super(key: key);

  @override
  State<SafetyScoreWidget> createState() => _SafetyScoreWidgetState();
}

class _SafetyScoreWidgetState extends State<SafetyScoreWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.score / 100.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: SafetyScorePainter(
                  progress: _animation.value,
                  score: widget.score.toDouble(),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.score}',
                        style: TextStyle(
                          fontSize: widget.size * 0.25,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(widget.score.toDouble()),
                        ),
                      ),
                      Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: widget.size * 0.08,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 8),
          Text(
            widget.label ?? _getScoreLabel(widget.score.toDouble()),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _getScoreColor(widget.score.toDouble()),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.safetyGood;
    if (score >= 60) return AppColors.safetyMedium;
    return AppColors.safetyPoor;
  }

  String _getScoreLabel(double score) {
    if (score >= 90) return 'Excelente';
    if (score >= 80) return 'Muito Bom';
    if (score >= 70) return 'Bom';
    if (score >= 60) return 'Regular';
    if (score >= 40) return 'Ruim';
    return 'Muito Ruim';
  }
}

class SafetyScorePainter extends CustomPainter {
  final double progress;
  final double score;

  SafetyScorePainter({
    required this.progress,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle
    final backgroundPaint = Paint()
      ..color = AppColors.textTertiary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = _getScoreColor(score)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Gradient effect
    if (progress > 0) {
      final gradientPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            _getScoreColor(score).withOpacity(0.3),
            _getScoreColor(score).withOpacity(0.1),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        gradientPaint,
      );
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.safetyGood;
    if (score >= 60) return AppColors.safetyMedium;
    return AppColors.safetyPoor;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SafetyScorePainter &&
        (oldDelegate.progress != progress || oldDelegate.score != score);
  }
}

