import 'dart:math';
import 'package:flutter/material.dart';
import '../services/safety_score_service.dart';

class SafetyScoreWidget extends StatelessWidget {
  final SafetyResult result;
  final VoidCallback? onTap;

  const SafetyScoreWidget({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(result.colorValue);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Safety Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Gauge + score number
            Row(
              children: [
                // Gauge
                SizedBox(
                  width: 100,
                  height: 60,
                  child: CustomPaint(
                    painter: _GaugePainter(score: result.score, color: color),
                  ),
                ),
                const SizedBox(width: 16),
                // Score number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${result.score}',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const TextSpan(
                            text: '/100',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Tap for details',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Score breakdown bars
            _ScoreBar(
              icon: Icons.access_time,
              label: 'Time',
              sublabel: result.timeLabel,
              score: result.timeScore,
              color: color,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              icon: Icons.location_on,
              label: 'Location',
              sublabel: result.locationLabel,
              score: result.locationScore,
              color: color,
            ),
            const SizedBox(height: 8),
            _ScoreBar(
              icon: Icons.warning_amber,
              label: 'Area alerts',
              sublabel: result.alertLabel,
              score: result.alertScore,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Score bar widget ──────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final int score;
  final Color color;

  const _ScoreBar({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('$score',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Gauge painter ─────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 4;
    final radius = size.width / 2 - 4;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi,
      pi * (score / 100),
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}