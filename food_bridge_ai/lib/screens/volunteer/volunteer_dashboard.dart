import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/donation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/donation_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shimmer_list.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/risk_badge.dart';
import '../../widgets/countdown_timer.dart';
import 'active_task_screen.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  bool _isAvailable = false;
  bool _initialized = false;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) NotificationService.requestPermissions().catchError((_) => null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = context.read<app_auth.AuthProvider>();
      final loaded = auth.userModel?.isAvailable;
      if (loaded != null) {
        _isAvailable = loaded;
        _initialized = true;
        if (_isAvailable && auth.firebaseUser != null) {
          _startLocationUpdates(auth.firebaseUser!.uid);
        }
      }
    }
  }

  void _startLocationUpdates(String uid) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).listen((Position position) {
      FirebaseService.updateUserLocation(
        uid,
        UserLocation(lat: position.latitude, lng: position.longitude),
      ).catchError((_) {}); // Ignore transient connection errors
    });
  }

  void _stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final user = auth.userModel;
    final uid = auth.firebaseUser?.uid ?? '';
    final donationProv = context.watch<DonationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF060E07),
      body: Stack(
        children: [
          // Hero energy glow — top right
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF00C853).withOpacity(0.18), Colors.transparent]),
              ),
            ),
          ),
          // Secondary glow — bottom left
          Positioned(
            bottom: 120, left: -60,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF64DD17).withOpacity(0.12), Colors.transparent]),
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
                    // ── Header Row ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Text('🏃', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 6),
                                Text('Ready to help?',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF558B2F), fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 4),
                              ShaderMask(
                                shaderCallback: (b) => const LinearGradient(
                                  colors: [Color(0xFF76FF03), Color(0xFF00E676)],
                                ).createShader(b),
                                child: Text(
                                  user?.name ?? 'Volunteer',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                                      color: Colors.white, letterSpacing: -0.3),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFD600), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${user?.rating.toStringAsFixed(1) ?? "5.0"} · Community helper',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        // Online/Offline toggle column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isAvailable
                                    ? const Color(0xFF1B5E20).withOpacity(0.8)
                                    : const Color(0xFF1A2410),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isAvailable ? const Color(0xFF00E676) : const Color(0xFF2E3D1F),
                                  width: 1.5,
                                ),
                                boxShadow: _isAvailable ? [
                                  BoxShadow(color: const Color(0xFF00C853).withOpacity(0.4), blurRadius: 12),
                                ] : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isAvailable ? const Color(0xFF76FF03) : const Color(0xFF33691E),
                                      boxShadow: _isAvailable
                                          ? [BoxShadow(color: const Color(0xFF76FF03).withOpacity(0.8), blurRadius: 8)]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isAvailable ? '🟢 Online' : '⚫ Offline',
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800,
                                      color: _isAvailable ? const Color(0xFF76FF03) : const Color(0xFF558B2F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isAvailable,
                              onChanged: uid.isEmpty ? null : (v) async {
                                setState(() => _isAvailable = v);
                                if (v) {
                                  _startLocationUpdates(uid);
                                } else {
                                  _stopLocationUpdates();
                                }
                                try {
                                  await FirebaseService.updateAvailability(uid, v);
                                } catch (e) {
                                  setState(() => _isAvailable = !v);
                                  if (!v) {
                                    _startLocationUpdates(uid);
                                  } else {
                                    _stopLocationUpdates();
                                  }
                                }
                              },
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF00C853),
                              inactiveThumbColor: Colors.white60,
                              inactiveTrackColor: const Color(0xFF1A2410),
                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                    const SizedBox(height: 20),

                    // ── Mission Banner ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A1F0C), Color(0xFF122B14)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00C853).withOpacity(0.25)),
                      ),
                      child: const Row(children: [
                        Text('💚', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your mission today',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF00E676))),
                              SizedBox(height: 2),
                              Text('Pick up surplus food and deliver it to those who need it most.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50), height: 1.4)),
                            ],
                          ),
                        ),
                      ]),
                    ).animate(delay: 80.ms).fadeIn().slideX(begin: -0.05, end: 0),

                    const SizedBox(height: 20),

                    // ── Stats Row ─────────────────────────────────────────
                    StreamBuilder<List<DonationModel>>(
                      stream: FirebaseService.completedDonationsStream(uid, UserRole.volunteer),
                      builder: (context, snapshot) {
                        final donations = snapshot.data ?? [];
                        final count = donations.length;
                        return Row(
                          children: [
                            _VolStatCard(label: 'Deliveries', value: '$count', icon: Icons.delivery_dining_rounded, color: const Color(0xFF00E676))
                                .animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
                            const SizedBox(width: 10),
                            _VolStatCard(label: 'Points', value: '${user?.points ?? 0}', icon: Icons.bolt_rounded, color: const Color(0xFFFFD600))
                                .animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
                            const SizedBox(width: 10),
                            _BadgeCard(deliveries: count)
                                .animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // ── Task section label ────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF00E676), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isAvailable ? 'Your Assigned Tasks' : "You're Offline",
                          style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: Color(0xFFE8F5E9), letterSpacing: -0.3,
                          ),
                        ),
                        if (_isAvailable) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
                            ),
                            child: const Text('Live', style: TextStyle(fontSize: 11, color: Color(0xFF76FF03), fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ).animate(delay: 150.ms).fadeIn(),

                    const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ── Task List / Offline ────────────────────────────────────────
                if (!_isAvailable)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('😴', style: TextStyle(fontSize: 64))
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.08, 1.08), duration: 1200.ms),
                          const SizedBox(height: 16),
                          const Text("You're Taking a Break",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFE8F5E9))),
                          const SizedBox(height: 8),
                          const Text(
                            'Toggle Online to start receiving\ndelivery tasks from NGOs near you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF4CAF50), height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: StreamBuilder<List<DonationModel>>(
                      stream: donationProv.volunteerTasksStream(uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SliverToBoxAdapter(child: ShimmerLoadingList());
                        }
                        if (snap.hasError) {
                          return const SliverToBoxAdapter(
                            child: EmptyStateWidget(
                              icon: Icons.cloud_off_rounded,
                              message: 'Offline Mode',
                              subMessage: 'Tasks will appear when reconnected',
                            ),
                          );
                        }
                        if (!snap.hasData || snap.data!.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: EmptyStateWidget(
                              icon: Icons.emoji_events_outlined,
                              message: 'No tasks assigned yet',
                              subMessage: 'NGOs will assign tasks to you soon!',
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TaskCard(donation: snap.data![i], uid: uid)
                                  .animate(delay: Duration(milliseconds: 60 * i))
                                  .fadeIn()
                                  .slideX(begin: 0.06, end: 0),
                            ),
                            childCount: snap.data!.length,
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

// ── Stat Card ────────────────────────────────────────────────────────────────
class _VolStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _VolStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 14),
          const BoxShadow(color: AppColors.shadowDark, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMedium)),
        ],
      ),
    ),
  );
}

// ── Badge Card ────────────────────────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final int deliveries;
  const _BadgeCard({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    String badge; Color color;
    if (deliveries >= 100) { badge = '⚔️ Warrior'; color = AppColors.mossGreen; }
    else if (deliveries >= 50) { badge = '🏆 Champion'; color = AppColors.teal; }
    else if (deliveries >= 10) { badge = '🌟 Hero'; color = AppColors.amber; }
    else { badge = '🌱 Starter'; color = AppColors.textLight; }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 14)],
        ),
        child: Column(
          children: [
            Text(badge.split(' ')[0], style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(badge.split(' ')[1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const Text('Rank', style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
          ],
        ),
      ),
    );
  }
}

// ── Task Card ────────────────────────────────────────────────────────────────
class _TaskCard extends StatefulWidget {
  final DonationModel donation;
  final String uid;
  const _TaskCard({required this.donation, required this.uid});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() => _processing = true);
    final auth = context.read<app_auth.AuthProvider>();
    final prov = context.read<DonationProvider>();
    final user = auth.userModel;
    final ok = await prov.acceptTask(
      widget.donation.id,
      volunteerId: widget.uid,
      volunteerName: user?.name,
    );
    if (ok && mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ActiveTaskScreen(donation: widget.donation),
          transitionsBuilder: (_, a, __, c) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: c,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept task. Please try again.'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _decline() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Decline Task?', style: TextStyle(color: AppColors.textDark)),
        content: const Text('This task will go back to the NGO.', style: TextStyle(color: AppColors.textMedium)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMedium))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.riskHigh),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _processing = true);
      try {
        await FirebaseService.declineTask(widget.donation.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task declined')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not mark as completed. Check connection.')));
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.donation;
    final matchScore = 85 + (d.riskScore * 3).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E3D2E), width: 1),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowDark, blurRadius: 16, offset: Offset(0, 6)),
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
                  color: AppColors.darkCardAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.mossGreen.withOpacity(0.4), width: 1.5),
                ),
                child: Center(child: Text(d.category.icon, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(d.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        RiskBadge(risk: d.riskLabel),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.category.displayName} • ${d.quantityKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.mossGreen),
                    ),
                    Text('From ${d.donorName}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(d.pickupLocation.address,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.purpleGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("You're $matchScore% best fit",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const Spacer(),
              CountdownTimer(expiryTime: d.expiryTime, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing ? null : _decline,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.riskHigh),
                    foregroundColor: AppColors.riskHigh,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.mintGradient),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.mossGreen.withOpacity(0.3), blurRadius: 12)],
                  ),
                  child: ElevatedButton(
                    onPressed: _processing ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _processing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Accept Task',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
