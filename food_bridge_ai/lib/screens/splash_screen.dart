import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../utils/app_colors.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/user_model.dart';
import 'main_shell.dart';
import 'auth/login_screen.dart';

// ─── Splash ──────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final auth = context.read<app_auth.AuthProvider>();
    if (auth.isAuthenticated && auth.userModel != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RoleSelectionScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background radial glow
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.forestGreen.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.amber.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: AppColors.mossGreen.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mossGreen.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 58,
                    color: AppColors.mossGreen,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.0, 0.0),
                      end: const Offset(1.0, 1.0),
                      duration: 900.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 36),

                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.mossGreen, AppColors.lightGreen],
                  ).createShader(bounds),
                  child: const Text(
                    'Food Flow AI',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 700.ms)
                    .slideY(begin: 0.3, end: 0, delay: 400.ms, curve: Curves.easeOut),

                const SizedBox(height: 10),

                const Text(
                  'Connecting surplus with communities',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMedium,
                    letterSpacing: 0.3,
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 600.ms),

                const SizedBox(height: 70),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.mossGreen,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.mossGreen.withOpacity(0.8), blurRadius: 8)],
                      ),
                    ).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 700.ms).then().fadeIn(duration: 700.ms),
                    const SizedBox(width: 6),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: AppColors.mossGreen.withOpacity(0.5), shape: BoxShape.circle),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 700.ms, delay: 200.ms).then().fadeIn(duration: 700.ms),
                    const SizedBox(width: 6),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: AppColors.mossGreen.withOpacity(0.3), shape: BoxShape.circle),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 700.ms, delay: 400.ms).then().fadeIn(duration: 700.ms),
                  ],
                ).animate().fadeIn(delay: 1300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Role Selection ───────────────────────────────────────────────────────────

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selected;

  void _selectRole(UserRole role) {
    setState(() => _selected = role);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginScreen(role: role),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.forestGreen.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo row
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.mossGreen.withOpacity(0.4)),
                          boxShadow: [BoxShadow(color: AppColors.mossGreen.withOpacity(0.2), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.eco_rounded, color: AppColors.mossGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [AppColors.mossGreen, AppColors.lightGreen],
                        ).createShader(b),
                        child: const Text(
                          'Food Flow AI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 48),

                  const Text(
                    'How will you\nhelp today?',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                  const SizedBox(height: 10),

                  const Text(
                    'Choose your role to get started',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMedium,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 36),

                  _RoleCard(
                    delay: 300.ms,
                    icon: Icons.restaurant_rounded,
                    title: 'I have surplus food',
                    subtitle: 'Donate excess food from your restaurant, event, or kitchen',
                    role: 'Donor',
                    gradientColors: AppColors.amberGradient,
                    glowColor: AppColors.amber,
                    isSelected: _selected == UserRole.donor,
                    onTap: () => _selectRole(UserRole.donor),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    delay: 420.ms,
                    icon: Icons.volunteer_activism_rounded,
                    title: 'We distribute to communities',
                    subtitle: 'As an NGO, collect and redistribute food to those in need',
                    role: 'NGO',
                    gradientColors: const [AppColors.teal, Color(0xFF00E5D4)],
                    glowColor: AppColors.teal,
                    isSelected: _selected == UserRole.ngo,
                    onTap: () => _selectRole(UserRole.ngo),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    delay: 540.ms,
                    icon: Icons.delivery_dining_rounded,
                    title: 'I want to help deliver',
                    subtitle: 'Pick up donations and bring food to communities',
                    role: 'Volunteer',
                    gradientColors: AppColors.purpleGradient,
                    glowColor: AppColors.purple,
                    isSelected: _selected == UserRole.volunteer,
                    onTap: () => _selectRole(UserRole.volunteer),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final Duration delay;
  final IconData icon;
  final String title;
  final String subtitle;
  final String role;
  final List<Color> gradientColors;
  final Color glowColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.delay,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.role,
    required this.gradientColors,
    required this.glowColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isSelected
                  ? widget.glowColor.withOpacity(0.7)
                  : const Color(0xFF1E3D2E),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(color: widget.glowColor.withOpacity(0.25), blurRadius: 24, spreadRadius: 2),
                    const BoxShadow(color: AppColors.shadowDark, blurRadius: 16, offset: Offset(0, 6)),
                  ]
                : [const BoxShadow(color: AppColors.shadowDark, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: widget.glowColor.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: widget.isSelected
                    ? Icon(Icons.check_circle_rounded, color: widget.glowColor, size: 26, key: const ValueKey('check'))
                    : const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textLight, size: 16, key: ValueKey('arrow')),
              ),
            ],
          ),
        )
            .animate(delay: widget.delay)
            .slideX(begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 450.ms),
      ),
    );
  }
}
