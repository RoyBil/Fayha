import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/choir_data.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _lineGrow;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)),
    );
    _lineGrow = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
    );
    _textFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 5000), _goNext);
  }

  bool _precached = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage('assets/logo/logo_dark.png'), context);
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [AppColors.primary, AppColors.primaryDark, AppColors.charcoal],
            radius: 1.2,
            center: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative corner accent
              Positioned(
                top: -60, right: -60,
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -80, left: -80,
                child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Centered content
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FadeTransition(
                              opacity: _logoFade,
                              child: ScaleTransition(
                                scale: _logoScale,
                                child: const _Monogram(),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Container(
                              height: 2,
                              width: 64 * _lineGrow.value,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accent.withValues(alpha: 0.0),
                                    AppColors.accent,
                                    AppColors.accent.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            FadeTransition(
                              opacity: _textFade,
                              child: Column(
                                children: [
                                  Text(
                                    'Fayha National Choir',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cormorantGaramond(
                                      color: AppColors.cream,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'A CAPPELLA · EST. ${ChoirData.founded}',
                                    style: GoogleFonts.inter(
                                      color: AppColors.accentLight,
                                      fontSize: 11,
                                      letterSpacing: 4.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 80, height: 2,
                              child: LinearProgressIndicator(
                                backgroundColor:
                                    AppColors.cream.withValues(alpha: 0.12),
                                color: AppColors.accent,
                                minHeight: 2,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Voices of Lebanon',
                              style: GoogleFonts.cormorantGaramond(
                                color: AppColors.cream.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Image.asset(
        'assets/logo/logo_dark.png',
        width: (MediaQuery.of(context).size.width * 0.7).clamp(180.0, 360.0),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          final w = (MediaQuery.of(context).size.width * 0.7).clamp(180.0, 360.0);
          return SizedBox(width: w, height: w * 0.55);
        },
        errorBuilder: (_, __, ___) => SizedBox(
          width: 140, height: 140,
          child: Center(
            child: Text(
              'F',
              style: GoogleFonts.cormorantGaramond(
                color: AppColors.cream,
                fontSize: 96,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
