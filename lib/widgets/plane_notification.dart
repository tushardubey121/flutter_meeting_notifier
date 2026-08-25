import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meeting.dart';

class PlaneNotificationOverlay extends StatefulWidget {
  final Meeting meeting;
  final VoidCallback onDismiss;
  final double screenWidth;

  const PlaneNotificationOverlay({
    super.key,
    required this.meeting,
    required this.onDismiss,
    required this.screenWidth,
  });

  @override
  State<PlaneNotificationOverlay> createState() =>
      _PlaneNotificationOverlayState();
}

class _PlaneNotificationOverlayState extends State<PlaneNotificationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _planeController;
  late AnimationController _flagController;
  late AnimationController _flagWaveController;
  late AnimationController _fadeController;

  late Animation<double> _planeX;
  late Animation<double> _planeY;
  late Animation<double> _flagTrail;
  late Animation<double> _flagWave;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  bool _isDismissing = false;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();

    // Slow, majestic crossing — takes ~20 seconds to traverse the screen
    _planeController = AnimationController(
      duration: const Duration(milliseconds: 20000),
      vsync: this,
    );

    _flagController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _flagWaveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Plane travels from off the left edge to off the right edge of the full
    // screen at a constant, calm speed. Begin offset accounts for the towed
    // banner (~520px of content) so everything starts fully off-screen.
    _planeX = Tween<double>(begin: -520, end: widget.screenWidth + 40)
        .animate(_planeController);

    // Gentle bobbing motion
    _planeY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(_planeController);

    _flagTrail = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flagController, curve: Curves.elasticOut),
    );

    _flagWave = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _flagWaveController, curve: Curves.easeInOut),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.5, 1, curve: Curves.easeOut),
      ),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await _fadeController.animateTo(0.5,
        duration: const Duration(milliseconds: 300));

    if (mounted) setState(() => _showBanner = true);
    _flagController.forward();

    // The full crossing takes ~17s; dismiss once the plane exits the screen
    await _planeController.forward();
    if (mounted && !_isDismissing) {
      _dismiss();
    }
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    setState(() => _isDismissing = true);
    await _fadeController.animateTo(1.0,
        duration: const Duration(milliseconds: 400));
    if (mounted) widget.onDismiss();
  }

  Future<void> _joinMeeting() async {
    if (widget.meeting.meetLink != null) {
      final uri = Uri.parse(widget.meeting.meetLink!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    _dismiss();
  }

  @override
  void dispose() {
    _planeController.dispose();
    _flagController.dispose();
    _flagWaveController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _planeController,
        _flagController,
        _flagWaveController,
        _fadeController,
      ]),
      builder: (context, _) {
        final opacity = _isDismissing ? _fadeOut.value : _fadeIn.value;

        return Opacity(
          opacity: opacity,
          // A click anywhere in the strip (outside the banner) dismisses the
          // overlay immediately so it never gets in the user's way.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismiss,
            child: Stack(
              children: [
                // Semi-transparent background strip across the full screen width
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  height: 110,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Banner towed behind the plane — positioned absolutely so it
                // travels the full width
                Positioned(
                  top: 70 + _planeY.value,
                  left: _planeX.value,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_showBanner)
                        Transform.rotate(
                          angle: _flagWave.value,
                          alignment: Alignment.centerRight,
                          child: _buildFlagBanner(),
                        ),
                      if (_showBanner)
                        Container(
                          width: 48 * _flagTrail.value,
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      const SizedBox(width: 8),
                      _buildPlane(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlane() {
    // Lottie plane if assets/plane.json is provided; otherwise falls back
    // to the built-in drawn plane.
    return Lottie.asset(
      'assets/plane.json',
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      repeat: true,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        size: const Size(72, 72),
        painter: _PlanePainter(),
      ),
    );
  }

  Widget _buildFlagBanner() {
    return GestureDetector(
      onTap: widget.meeting.hasMeetLink ? _joinMeeting : _dismiss,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.meeting.timeUntilLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.meeting.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.meeting.formattedTime,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.meeting.hasMeetLink)
                    ElevatedButton(
                      onPressed: _joinMeeting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Join',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Icon(
                      Icons.event,
                      color: Colors.white70,
                      size: 28,
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    // Fuselage
    paint.color = const Color(0xFFECEFF1);
    final fuselage = Path()
      ..moveTo(-30, -6)
      ..cubicTo(-30, -10, 28, -10, 32, -4)
      ..cubicTo(36, 0, 32, 6, 28, 6)
      ..lineTo(-28, 6)
      ..cubicTo(-32, 6, -34, 2, -30, -6)
      ..close();
    canvas.drawPath(fuselage, paint);

    // Cockpit windows
    paint.color = const Color(0xFF90CAF9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, -4, 12, 8),
        const Radius.circular(3),
      ),
      paint,
    );

    // Main wing
    paint.color = const Color(0xFF1565C0);
    final wing = Path()
      ..moveTo(-4, -5)
      ..lineTo(8, -5)
      ..lineTo(4, -26)
      ..lineTo(-18, -22)
      ..close();
    canvas.drawPath(wing, paint);

    // Wing underside
    paint.color = const Color(0xFF0D47A1);
    final wingUnder = Path()
      ..moveTo(-4, 5)
      ..lineTo(8, 5)
      ..lineTo(4, 22)
      ..lineTo(-16, 20)
      ..close();
    canvas.drawPath(wingUnder, paint);

    // Tail fin
    paint.color = const Color(0xFF1565C0);
    final tail = Path()
      ..moveTo(-24, -5)
      ..lineTo(-18, -5)
      ..lineTo(-16, -18)
      ..lineTo(-28, -14)
      ..close();
    canvas.drawPath(tail, paint);

    // Horizontal stabilizer
    final stab = Path()
      ..moveTo(-30, 0)
      ..lineTo(-18, 0)
      ..lineTo(-20, 10)
      ..lineTo(-32, 8)
      ..close();
    canvas.drawPath(stab, paint);

    // Engine
    paint.color = const Color(0xFF37474F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2, 5, 18, 7),
        const Radius.circular(3),
      ),
      paint,
    );

    // Engine inlet
    paint.color = const Color(0xFF263238);
    canvas.drawOval(
      const Rect.fromLTWH(-2, 6, 8, 6),
      paint,
    );

    // Exhaust trail
    paint.color = Colors.white.withValues(alpha: 0.4);
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(-34.0 - i * 8, 0),
        2.0 - i * 0.3,
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
