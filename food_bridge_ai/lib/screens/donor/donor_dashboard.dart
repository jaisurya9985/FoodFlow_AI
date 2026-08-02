import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/donation_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/donation_provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/shimmer_list.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/countdown_timer.dart';
import 'donation_form.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DonationProvider>().cleanupExpired();
    });
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final user = auth.userModel;
    final uid = auth.firebaseUser?.uid ?? '';
    final donationProv = context.watch<DonationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0A06),
      body: Stack(
        children: [
          // Warm ambient glow — top-left
          Positioned(
            top: -80, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFF7043).withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Secondary warm glow — bottom-right
          Positioned(
            bottom: 120, right: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFFB300).withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Floating food emojis (decorative)
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              top: 80 + (_floatController.value * 12),
              right: 30,
              child: const Opacity(
                opacity: 0.12,
                child: Text('🍱', style: TextStyle(fontSize: 48)),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              top: 200 - (_floatController.value * 8),
              left: 10,
              child: const Opacity(
                opacity: 0.08,
                child: Text('🍲', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Text('🍽️', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_greeting()}, generous soul!',
                                      style: const TextStyle(
                                        fontSize: 13, color: Color(0xFFBB8860),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  ShaderMask(
                                    shaderCallback: (b) => const LinearGradient(
                                      colors: [Color(0xFFFF8C42), Color(0xFFFFD166)],
                                    ).createShader(b),
                                    child: Text(
                                      user?.name ?? 'Friend',
                                      style: const TextStyle(
                                        fontSize: 26, fontWeight: FontWeight.w900,
                                        color: Colors.white, letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Row(children: [
                                    Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 13),
                                    SizedBox(width: 4),
                                    Text('Food donor & community hero',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF8A6F5A))),
                                  ]),
                                ],
                              ),
                            ),
                            // Avatar with warm border
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (_, child) => Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(colors: [
                                    Color.lerp(const Color(0xFFFF7043), const Color(0xFFFFB300), _pulseController.value)!,
                                    Color.lerp(const Color(0xFFFFB300), const Color(0xFFFF4B9B), _pulseController.value)!,
                                  ]),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF7043).withOpacity(0.4 + _pulseController.value * 0.2),
                                      blurRadius: 18, spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A0F06),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Center(
                                    child: Text(
                                      user?.initials ?? 'U',
                                      style: const TextStyle(
                                        color: Color(0xFFFF8C42), fontWeight: FontWeight.w900, fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                        const SizedBox(height: 24),

                        // ── Motivational Banner ──────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A0F06), Color(0xFF2C1A0A)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFF7043).withOpacity(0.2)),
                          ),
                          child: const Row(children: [
                            Text('💡', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Every kg you donate saves 2 meals and prevents 2.5 kg of CO₂ emissions.',
                                style: TextStyle(
                                  fontSize: 12, color: Color(0xFFBB8860), height: 1.4,
                                ),
                              ),
                            ),
                          ]),
                        ).animate(delay: 50.ms).fadeIn().slideX(begin: -0.05, end: 0),

                        const SizedBox(height: 20),

                        // ── Impact Stats ─────────────────────────────────────
                        const Text('Your Impact', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF8A6F5A), letterSpacing: 0.8,
                        )),
                        const SizedBox(height: 8),
                        StreamBuilder<List<DonationModel>>(
                          stream: FirebaseService.completedDonationsStream(uid, UserRole.donor),
                          builder: (context, snapshot) {
                            final donations = snapshot.data ?? [];
                            final totalKg = donations.fold<double>(0, (s, d) => s + d.quantityKg);
                            final meals = (totalKg * 2.0).toInt();
                            final co2 = totalKg * 2.5;
                            return Row(
                              children: [
                                _DonorStatCard(label: 'kg Donated', value: totalKg.toStringAsFixed(1),
                                    icon: '🌾', color: const Color(0xFFFF8C42))
                                    .animate(delay: 100.ms).fadeIn().slideY(begin: 0.3, end: 0),
                                const SizedBox(width: 10),
                                _DonorStatCard(label: 'Meals helped', value: '$meals',
                                    icon: '🍜', color: const Color(0xFFFFD166))
                                    .animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0),
                                const SizedBox(width: 10),
                                _DonorStatCard(label: 'CO₂ Saved', value: '${co2.toStringAsFixed(1)} kg',
                                    icon: '🌿', color: const Color(0xFF00C97B))
                                    .animate(delay: 300.ms).fadeIn().slideY(begin: 0.3, end: 0),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── CTA — Post Food ──────────────────────────────────
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => const DonationForm(),
                              transitionsBuilder: (_, a, __, c) => SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                                child: c,
                              ),
                              transitionDuration: const Duration(milliseconds: 450),
                            ),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 22),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B2C), Color(0xFFFF8C42), Color(0xFFFFD166)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFF7043).withOpacity(0.5),
                                    blurRadius: 24, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🍱', style: TextStyle(fontSize: 26)),
                                SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Donate Surplus Food',
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                                            color: Colors.white, letterSpacing: 0.2)),
                                    Text('Share what you can — every bite matters',
                                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                                  ],
                                ),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                              ],
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true, period: const Duration(seconds: 3)))
                              .shimmer(duration: 900.ms, color: Colors.white.withOpacity(0.3))
                              .animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                        ),

                        const SizedBox(height: 28),

                        // ── Active Donations Label ────────────────────────────
                        Row(children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          const Text('Your Active Donations',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                                  color: Color(0xFFF0E0D0), letterSpacing: -0.3)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7043).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF7043).withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (_, __) => Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color.lerp(const Color(0xFFFF7043), const Color(0xFFFFD166), _pulseController.value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text('Live', style: TextStyle(fontSize: 11, color: Color(0xFFFF8C42), fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ]).animate(delay: 200.ms).fadeIn(),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ── Donations List ───────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: StreamBuilder<List<DonationModel>>(
                    stream: donationProv.donorStream(uid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(child: ShimmerLoadingList());
                      }
                      if (snap.hasError) {
                        return const SliverToBoxAdapter(
                          child: EmptyStateWidget(
                            icon: Icons.cloud_off_rounded,
                            message: 'Offline Mode',
                            subMessage: 'We\'ll refresh when you\'re back online',
                          ),
                        );
                      }
                      final activeDonations = (snap.data ?? [])
                          .where((d) => !d.isExpired && d.status != DonationStatus.delivered)
                          .toList();
                      if (activeDonations.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Column(children: [
                            const SizedBox(height: 30),
                            const Text('🌟', style: TextStyle(fontSize: 60)).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1.0, 1.0), end: const Offset(1.1, 1.1), duration: 1200.ms),
                            const SizedBox(height: 16),
                            const Text('Be the first to share today!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF0E0D0))),
                            const SizedBox(height: 8),
                            const Text('Post surplus food to help your community.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Color(0xFF8A6F5A), height: 1.5)),
                          ]),
                        );
                      }
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DonorDonationCard(donation: activeDonations[i])
                                .animate(delay: Duration(milliseconds: 50 * i))
                                .fadeIn()
                                .slideX(begin: 0.05, end: 0),
                          ),
                          childCount: activeDonations.length,
                        ),
                      );
                    },
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Donor Stat Card ─────────────────────────────────────────────────────────

class _DonorStatCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _DonorStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF140C05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8A6F5A)), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Donation Card ────────────────────────────────────────────────────────────

class _DonorDonationCard extends StatefulWidget {
  final DonationModel donation;
  const _DonorDonationCard({required this.donation});

  @override
  State<_DonorDonationCard> createState() => _DonorDonationCardState();
}

class _DonorDonationCardState extends State<_DonorDonationCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.donation.status) {
      case DonationStatus.matched: return const Color(0xFF00BCD4);
      case DonationStatus.accepted: return const Color(0xFF9C6FFF);
      case DonationStatus.pickedUp: return const Color(0xFF9C6FFF);
      case DonationStatus.delivered: return const Color(0xFF00E5A0);
      default: return const Color(0xFFFF8C42);
    }
  }

  IconData get _statusIcon {
    switch (widget.donation.status) {
      case DonationStatus.matched: return Icons.handshake_rounded;
      case DonationStatus.accepted: return Icons.check_circle_rounded;
      case DonationStatus.pickedUp: return Icons.delivery_dining_rounded;
      case DonationStatus.delivered: return Icons.favorite_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String get _statusLabel {
    switch (widget.donation.status) {
      case DonationStatus.matched: return 'NGO Claimed ✓';
      case DonationStatus.accepted: return 'Volunteer Accepted ✓';
      case DonationStatus.pickedUp: return 'On the Way 🚴';
      case DonationStatus.delivered: return 'Delivered 💚';
      default: return 'Awaiting Pickup';
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF160C04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _statusColor.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(color: _statusColor.withOpacity(0.1), blurRadius: 16),
            const BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      _statusColor.withOpacity(0.2), const Color(0xFF1A0F06),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Center(child: Text(d.category.icon, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFF0E0D0)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${d.quantityKg.toStringAsFixed(0)} kg · ${d.category.displayName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F5A))),
                    ],
                  ),
                ),
                RiskBadge(risk: d.riskLabel),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(children: [
                    Icon(_statusIcon, color: _statusColor, size: 12),
                    const SizedBox(width: 5),
                    Text(_statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
                  ]),
                ),
                const Spacer(),
                CountdownTimer(expiryTime: d.expiryTime, compact: true),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF5A4030), size: 18,
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Container(height: 1, color: const Color(0xFF2C1A0A)),
                  const SizedBox(height: 12),
                  if (d.description.isNotEmpty) ...[
                    Text(d.description,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8A6F5A), height: 1.5)),
                    const SizedBox(height: 8),
                  ],
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF5A4030)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(d.pickupLocation.address,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8A6F5A)),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  if (d.matchedNGOName != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Text('🏛️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text('Matched NGO: ${d.matchedNGOName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00BCD4))),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
